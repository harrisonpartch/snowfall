MODULE Snowfall;	

IMPORT
	Raster, Random, Objects, WMRectangles, WMGraphics, Modules, Strings,
	WM := WMWindowManager, WMMessages, Out:=DebugLog;

CONST
	m = 250;
	size = 3;

	WindowWidth = m * size; WindowHeight = m * size;

TYPE

	KillerMsg = OBJECT
	END KillerMsg;

	TCW* =  OBJECT(WM.BufferWindow)
	VAR
		mesh1, mesh2, n1 : ARRAY m, m OF REAL;
		random : Random.Generator;
		alive, dead, pause, alpha, pdown : BOOLEAN;
		i : LONGINT;

		PROCEDURE &New*(alpha : BOOLEAN);
		VAR i, j : LONGINT;
		BEGIN
			Init(WindowWidth, WindowHeight, alpha);
			SELF.alpha :=alpha;
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing});

			SetTitle(Strings.NewString("Turing"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://Snowfall.png", TRUE));

			NEW(random);

			clear;
			FOR i :=  1 TO m - 2 DO
				FOR j := 1 TO m - 2 DO
					IF random.Dice(100) > 99 THEN mesh1[i, j] := random.Dice(1000)/1000 END
				END
			END;
			IncCount;
		END New;
		
		PROCEDURE clear;
		VAR i, j : LONGINT;
		BEGIN
			FOR i := 0 TO m - 1 DO
				FOR j := 0 TO m - 1 DO
					mesh1[i, j] := 0;
					mesh2[i, j] := 0;
					n1[i, j] := 0
				END
			END;
		END clear;		

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
		VAR i, j : LONGINT;
		BEGIN
			FOR i := 1 TO m - 2 DO
				n1[i, 0] := mesh1[i - 1, 0] + mesh1[i + 1, 0] + mesh1[i, m - 1] + mesh1[i, 1]
				 	+ mesh1[i - 1, m - 1] +  mesh1[i + 1, 1] + mesh1[i + 1, m - 1] + mesh1[i - 1,  1];
				n1[i, m - 1] := mesh1[i - 1, m - 1] + mesh1[i + 1, m - 1] + mesh1[i, m - 2] + mesh1[i, 0]
					+ mesh1[i - 1, m - 2] +  mesh1[i + 1, 0] + mesh1[i + 1, m - 2] + mesh1[i - 1, 0];
				END;
			FOR j := 1 TO m - 2 DO
				n1[0, j] := mesh1[m - 1, j] + mesh1[1, j] + mesh1[0, j - 1] + mesh1[0, j + 1]
					+ mesh1[m - 1, j - 1] +  mesh1[1, j + 1] + mesh1[1, j - 1] + mesh1[m - 1, j + 1];
				n1[m - 1, j] := mesh1[m - 2, j] + mesh1[0, j] + mesh1[m - 1, j - 1] + mesh1[m - 1, j + 1]
					+ mesh1[m - 2, j - 1] +  mesh1[0, j + 1] + mesh1[0, j - 1] + mesh1[m - 2, j + 1]
			END;

			FOR i := 1 TO m - 2 DO
				FOR j := 1 TO m - 2 DO
					n1[i, j] := mesh1[i - 1, j] + mesh1[i + 1, j] + mesh1[i, j - 1] + mesh1[i, j + 1]
						+ mesh1[i - 1, j - 1] +  mesh1[i + 1, j + 1] + mesh1[i + 1, j - 1] + mesh1[i - 1, j + 1]
				END
			END;
			FOR i := 1 TO m - 2 DO
				FOR j := 1 TO m - 2 DO
					(*  HERE ARE THE DIFFERENCE RULES! *)
					mesh1[i, j] := mesh1[i, j] + n1[i, j] / 80- (mesh2[i, j] * mesh2[i, j])  ;
					mesh2[i, j] := mesh2[i, j] +  mesh1[i, j] / 20 - 0.01 ;
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
					IF mesh1[i, j]=100 THEN 
						Raster.SetRGB(pix, 255, 0, 0)
					ELSE
						Raster.SetRGB(pix, SHORT((255-ENTIER(mesh1[i, j] * 255)) ), SHORT((255-ENTIER(mesh2[i, j] * 255)) ), 0)
					END;
					Raster.Fill(img, ix, jy, ix+size, jy+size, pix, mode)
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
	VAR
		i,j,wsize: LONGINT;
	BEGIN
		IF pdown THEN 
			wsize:= size*m;
			IF (x>size) & (x<wsize-size) &  (y>size) & (y<wsize-size) THEN
				FOR i:=(x DIV size) -1 TO (x DIV size) +1 DO
					FOR j:=(y DIV size) -1 TO (y DIV size) +1 DO
						mesh1[i,j] :=100
					END
				END
			END
		END
	END PointerMove;
	
	PROCEDURE KeyEvent (ucs : LONGINT; flags : SET; keysym : LONGINT);
	BEGIN
		CASE CHR(ucs) OF
			'p': pause:=~pause
			|'q': Close
			|'c': clear
ELSE
		END;
	END KeyEvent;

	BEGIN {ACTIVE}
		alive := TRUE;
		Objects.SetPriority(Objects.Low);
		Out.String("the snow is beginning to fall...");
		WHILE alive DO
			IF ~pause THEN
				Generation;
				DrawIt
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
END Snowfall.

SystemTools.Free Snowfall ~
Snowfall.OpenAlpha ~
Snowfall.Open ~
