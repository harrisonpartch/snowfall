MODULE Turing;	(* Soren Renner / TF *)

IMPORT
	Raster, Random, Objects, WMRectangles, WMGraphics, Modules, Strings,
	WM := WMWindowManager, WMMessages;


CONST
	m = 300;
	size = 2;

	WindowWidth = m * size; WindowHeight = m * size;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	TCW* =  OBJECT(WM.BufferWindow)
	VAR
		mesh1, mesh2, n1 : ARRAY m, m OF REAL;
		random : Random.Generator;
		alive, dead, pause, pdown: BOOLEAN;
		i, mousex, mousey : LONGINT;

		PROCEDURE &New*(alpha : BOOLEAN);
		VAR i, j : LONGINT;
		BEGIN
			Init(WindowWidth, WindowHeight, FALSE);
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing});

			SetTitle(Strings.NewString("Turing"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://TuringCoatWnd.png", TRUE));

			NEW(random);
			seed;
			IncCount;
		END New;
		
		PROCEDURE clear;
		VAR
			i,j: LONGINT;
		BEGIN
			FOR i := 0 TO m - 1 DO
				FOR j := 0 TO m - 1 DO
					mesh1[i, j] := 0;
					mesh2[i, j] := 0;
					n1[i, j] := 0
				END
			END;
		END clear;

		PROCEDURE seed;
		VAR
			i,j: LONGINT;
		BEGIN
			FOR i :=  0 TO m - 1 DO
				FOR j := 0 TO m - 1 DO
					IF random.Dice(100) > 97 THEN mesh1[i, j] := random.Dice(1000)/1000 END
				END
			END;
		END seed;		
		
		PROCEDURE Handle(VAR m: WMMessages.Message);
		BEGIN
			IF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) & (m.ext IS KillerMsg) THEN
				Close;
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE Draw*(canvas : WMGraphics.Canvas; w, h, q : LONGINT);
		BEGIN
			Draw^(canvas, w, h, 0)
		END Draw;

		PROCEDURE Close;
		BEGIN
			alive := FALSE;
			BEGIN {EXCLUSIVE} AWAIT(dead); END;
			Close^;
			DecCount;
		END Close;

		PROCEDURE Generation;
		VAR i,j, di,ii,dj,ij: LONGINT;
		BEGIN
			FOR i:= 0 TO m -1 DO
				di:=(i-1)MOD m;
				ii:=(i+1)MOD m;
				FOR j := 0 TO m-1 DO
					dj:=(j-1)MOD m;
					ij:=(j+1)MOD m;	
					n1[i, j] := mesh1[ii, dj] + mesh1[ii, j] + mesh1[ii, ij] + mesh1[i, dj]
								+ mesh1[i, ij] +  mesh1[di, dj] + mesh1[di, j] + mesh1[di, ij]
				END
			END;
			FOR i := 0 TO m - 1 DO
				FOR j := 0 TO m - 1 DO
					(*  HERE ARE THE DIFFERENCE RULES! *)
					mesh1[i, j] := mesh1[i, j] + n1[i, j] / 90 - (mesh2[i, j]*mesh2[i, j])  ; (* SELFPROMOTER *)
					mesh2[i, j] := mesh2[i, j] +  mesh1[i, j]/20 - 0.03;   (* POISON *)
					IF mesh1[i, j] < 0 THEN mesh1[i, j] := 0 END;
					IF mesh2[i, j] < 0 THEN mesh2[i, j] := 0 END;
					IF mesh1[i, j] > 1 THEN mesh1[i, j] := 1 END;
					IF mesh2[i, j] > 1 THEN mesh2[i, j] := 1 END;
				END;
			END;
		END Generation;

		PROCEDURE DrawIt;
		VAR i, j, ix, jy : LONGINT;
			pix : Raster.Pixel;
			mode : Raster.Mode;
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			FOR i := 0 TO m - 1 DO
				ix := i * size ;
				FOR j := 0 TO m - 1 DO
					jy := j * size;
					Raster.SetRGB(pix, SHORT((255-ENTIER(mesh1[i, j] * 255)) ), SHORT((255-ENTIER(mesh2[i, j] * 255)) ), 0);
;					Raster.Fill(img, ix, jy, ix+size, jy+size, pix, mode)
				END
			END;
			Invalidate(WMRectangles.MakeRect(0, 0, GetWidth(), GetHeight()))
		END DrawIt;	
	PROCEDURE PointerDown (x, y : LONGINT; keys : SET);
	BEGIN
		pdown:=TRUE;
	END PointerDown;
	
	PROCEDURE PointerUp (x, y : LONGINT; keys : SET);
	BEGIN
		pdown:=FALSE;
	END PointerUp;
	
	PROCEDURE PointerMove (x, y : LONGINT; keys : SET);
	BEGIN
		mousex:=x DIV size ;
		mousey:=y DIV size;
	END PointerMove;
			
	PROCEDURE KeyEvent (ucs : LONGINT; flags : SET; keysym : LONGINT);
	BEGIN
			CASE CHR(ucs) OF
				'p': pause:=~pause
				|'q': Close
				|'s': clear; seed
				|'x': clear
			ELSE
			END

	END KeyEvent;

	BEGIN {ACTIVE}
		alive := TRUE;
		Objects.SetPriority(Objects.Low);
		WHILE alive DO
			IF ~pause THEN
				IF pdown THEN
					mesh1[mousex,mousey]:= random.Dice(1000)/1000
				END;			
				Generation;
				DrawIt;
			END
		END;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END TCW;

VAR
	nofWindows : LONGINT;

PROCEDURE OpenAlpha*;
VAR window : TCW;
BEGIN
	NEW(window, TRUE);
END OpenAlpha;

PROCEDURE Open*;
VAR window : TCW;
BEGIN
	NEW(window, FALSE);
END Open;

PROCEDURE IncCount;
BEGIN {EXCLUSIVE}
	INC(nofWindows);
END IncCount;

PROCEDURE DecCount;
BEGIN {EXCLUSIVE}
	DEC(nofWindows);
END DecCount;

PROCEDURE Cleanup;
VAR die : KillerMsg;
	 msg : WMMessages.Message;
	 m : WM.WindowManager;
BEGIN {EXCLUSIVE}
	NEW(die); msg.ext := die; msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	AWAIT(nofWindows = 0);
END Cleanup;

BEGIN
	Modules.InstallTermHandler(Cleanup);
END Turing.

SystemTools.Free Turing ~
TuringCoatWnd.OpenAlpha ~
TuringCoatWnd.Open ~
