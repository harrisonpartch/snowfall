MODULE Turing;	(* Soren Renner / TF *)

IMPORT
	Kernel, Raster, Random, Objects, WMRectangles, WMGraphics, Modules, Strings,
	WM := WMWindowManager, WMMessages, Out:=KernelLog;


CONST
	M = 120;
	PSIZE = 1;
	T=3;
	TT=3*3;
	MDT= M DIV T;
	
	WindowWidth =M*T*PSIZE; WindowHeight = M*T*PSIZE;

TYPE
	KillerMsg = OBJECT
	END KillerMsg;
	
TYPE Tile=OBJECT
	VAR
		left, top, right, bottom: INTEGER;
		random : Random.Generator;	
		tileid: INTEGER;
		GO: BOOLEAN;
	
	PROCEDURE&New(l,t,r,b,tid:INTEGER);
	BEGIN
		left:=l; top:=t; right:=r; bottom:=b; tileid:=tid;
		NEW(random);
		seed;
	END New; 
	
	PROCEDURE go;
	BEGIN{EXCLUSIVE}
		GO:=TRUE
	END go;
	
	PROCEDURE clear;
		VAR
			i,j: LONGINT;
		BEGIN
			FOR i := top TO top+ MDT - 1 DO
				FOR j := left TO left + MDT - 1 DO
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
			FOR i :=  top TO top + MDT - 1 DO
				FOR j := left TO top + MDT - 1 DO
					IF random.Dice(100) > 97 THEN mesh1[i, j] := random.Dice(1000)/1000 END
				END
			END;
		END seed;		
	
	PROCEDURE generation;
	VAR i,j, di,ii,dj,ij: LONGINT;
	BEGIN		
(*		FOR i:= left+1 TO right-1 DO
			di:=(i-1)MOD M;
			ii:=(i+1)MOD M;
			FOR j := top-1 TO bottom+1 DO
				dj:=(j-1)MOD M;
				ij:=(j+1)MOD M;	
				n1[i, j] := mesh1[ii, dj] + mesh1[ii, j] + mesh1[ii, ij] + mesh1[i, dj]
							+ mesh1[i, ij] +  mesh1[di, dj] + mesh1[di, j] + mesh1[di, ij]
			END
		END;		
		FOR i := left+1 TO right-1 DO
			FOR j := top+1 TO bottom-1 DO
				(*  HERE ARE THE DIFFERENCE RULES! *)
				mesh1[i, j] := mesh1[i, j] + n1[i, j] / 90 - (mesh2[i, j]*mesh2[i, j])  ; (* SELFPROMOTER *)
				mesh2[i, j] := mesh2[i, j] +  mesh1[i, j]/20 - 0.03;   (* POISON *)
				IF mesh1[i, j] < 0 THEN mesh1[i, j] := 0 END;
				IF mesh2[i, j] < 0 THEN mesh2[i, j] := 0 END;
				IF mesh1[i, j] > 1 THEN mesh1[i, j] := 1 END;
				IF mesh2[i, j] > 1 THEN mesh2[i, j] := 1 END;
			END;
		END;
*)	END generation;	

BEGIN{ACTIVE, PRIORITY(Objects.Normal)}
	REPEAT
		BEGIN{EXCLUSIVE} AWAIT(GO) END;
		generation; 	
		BEGIN{EXCLUSIVE} INC(tilesdone) END;
		Out.Char('*'); 
		BEGIN{EXCLUSIVE}	GO:=FALSE END;
		Out.Int(tilesdone,4); 			
	UNTIL quit;

END Tile;

TYPE TileMaster=OBJECT
VAR
	i,j: INTEGER;
	timer: Kernel.Timer;
	
PROCEDURE & init;
BEGIN
	NEW(timer)
END init; 	


BEGIN {ACTIVE, PRIORITY(Objects.Normal)}
	NEW(timer);
	REPEAT 
		Out.Char('x');
		BEGIN{EXCLUSIVE} tilesdone:=0 END;		
		FOR i:= 0 TO T-1  DO
			FOR j:= 0 TO T-1 DO
				 tile[i,j].go
			END
		END;	
		BEGIN{EXCLUSIVE} AWAIT(tilesdone=TT) END;
		Out.Char('#');				
		timer.Sleep(100);
	UNTIL quit

END TileMaster;



	TCW* =  OBJECT(WM.BufferWindow)
	VAR
		alive, dead, pause, pdown: BOOLEAN;
		i, mousex, mousey : LONGINT;
		timer: Kernel.Timer;
		
		PROCEDURE &New*;
		VAR i, j : LONGINT;
		BEGIN
			Init(WindowWidth, WindowHeight, FALSE);
			manager := WM.GetDefaultManager();
			manager.Add(100, 100, SELF, {WM.FlagFrame, WM.FlagClose, WM.FlagNoResizing});
			SetTitle(Strings.NewString("|| Turing"));
			SetIcon(WMGraphics.LoadImage("WMIcons.tar://TuringCoatWnd.png", TRUE));
			IncCount;
			NEW(timer);
		END New;
		
		PROCEDURE Handle(VAR m: WMMessages.Message);
		BEGIN
			IF (m.msgType = WMMessages.MsgExt) & (m.ext # NIL) & (m.ext IS KillerMsg) THEN
				Close;
			ELSE Handle^(m)
			END
		END Handle;

		PROCEDURE Draw*(canpvas : WMGraphics.Canvas; w, h, q : LONGINT);
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
		
	PROCEDURE DrawIt;
		VAR ti, tj, i, j, ix, jy : LONGINT;
			pix : Raster.Pixel;
			mode : Raster.Mode;
		BEGIN
			Raster.InitMode(mode, Raster.srcCopy);
			FOR i:= 0 TO M-1 DO
					ix := i * PSIZE ;
					FOR j:= 0 TO M-1 DO
						jy := j * PSIZE;
(*						Raster.SetRGB(pix, SHORT((255-ENTIER(mesh1[i, j] * 255)) ), SHORT((255-ENTIER(mesh2[i, j] * 255)) ), SHORT((255-ENTIER(n1[i, j] * 255)) )  );
*)						Raster.SetRGB(pix,150,120,100);
						Raster.Fill(img, ix, jy, ix+PSIZE, jy+PSIZE, pix, mode)
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
		mousex:= ((x DIV PSIZE)-2)MOD M*T ;
		mousey:= ((y DIV PSIZE)-2)MOD M*T;
	END PointerMove;
			
	PROCEDURE KeyEvent (ucs : LONGINT; flags : SET; keysym : LONGINT);
	VAR
		i,j:INTEGER;
	BEGIN
(*		Out.Char(CHR(ucs)); *)
		CASE CHR(ucs) OF
			'p': pause:=~pause
			|'q': Close
			|'s': FOR i:= 0 TO T-1 DO 
					FOR j:=0 TO T-1 DO
						tile[i,j].clear;
						tile[i,j].seed
					END
				   END
			|'x': FOR i:= 0 TO T-1 DO 
					FOR j:=0 TO T-1 DO
						tile[i,j].clear
					END
				   END
		ELSE
		END
	END KeyEvent;
	
	BEGIN {ACTIVE, PRIORITY(Objects.Normal)}
		alive := TRUE;
		pause:=FALSE;
		REPEAT 
			IF ~pause THEN
				Out.Char('x');
(*				IF pdown THEN...*)
				BEGIN{EXCLUSIVE} tilesdone:=0 END;		
(*			tile[0,0].go;
			BEGIN{EXCLUSIVE} AWAIT(tilesdone=1) END;
			Out.Char('#');				
*)(*			FOR i:= 0 TO T-1  DO
				FOR j:= 0 TO T-1 DO
					 tile[i,j].go
				END
			END;			
			
			DrawIt;						
*)			END;
		timer.Sleep(100);	
		UNTIL FALSE;
		BEGIN {EXCLUSIVE} dead := TRUE; END;
	END TCW;

VAR
	mesh1, mesh2, n1 : ARRAY M,M OF REAL;
	quit: BOOLEAN;
	nofWindows: LONGINT;
	tile: ARRAY T,T OF Tile;
	tilemaster: TileMaster;
	a,b,i,j: INTEGER;
	tilesdone:INTEGER;
	left,top,bottom,right: INTEGER;

PROCEDURE gotiles;
VAR
	i,j: INTEGER;
BEGIN

END gotiles;

PROCEDURE Open*;
VAR window : TCW;
BEGIN
	NEW(window);
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
	FOR a:= 0 TO T-1  DO
		FOR b:= 0 TO T-1 DO
			NEW(tile[a,b],a*MDT,b*MDT,a*MDT+MDT-1,b*MDT+MDT-1,a*10+b) ;
		END
	END;	
	NEW(tilemaster);
END Turing.

SystemTools.Free Turing ~

Turing.Open ~
