// ---------------------------------------------------------------------------
// FixedCamera.zs - Resident Evil 1 style fixed camera angles.
//
// How RE1 does it (reference/re1-decomp/src/game/Room.cpp):
//   * A room has several cameras: a position, a point to look at, a lens.
//   * It also has "switch zones": 4-corner shapes on the floor, each with a
//     "from camera" and a "to camera".
//   * Every tick, check_camera_switch tests ONLY the zones that belong to the
//     current camera. The first one the player stands in cuts to its
//     "to camera". The cut is instant.
//
// We do exactly that. Cameras and zones are listed in mod/recams.txt.
// ---------------------------------------------------------------------------

// An invisible point the view is drawn from.
class REFixedCamera : Actor
{
	int camId;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
		RenderStyle "None";
		CameraHeight 0;
	}

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	// Aim the camera at a point, like RE1's "camera looks at" coordinate.
	void LookAt(Vector3 target)
	{
		Vector3 d = target - pos;
		Angle = VectorAngle(d.x, d.y);
		Pitch = -VectorAngle(d.xy.Length(), d.z);   // positive pitch = looking down
	}

	// How well does this camera show the actor?
	//   0     = not at all (outside the picture, too close, or behind a wall)
	//   0..1  = on screen; 1 would be dead centre
	// The whole body (feet to head, both sides) must be in the picture.
	// Not part of RE1: its rooms were drawn so the player was always in view.
	double ViewScore(Actor mo)
	{
		// GZDoom's FOV is the width of a 4:3 picture (wider screens only add
		// more at the sides). Doom pixels are drawn 1.2x taller, so the height
		// of the picture is 3/4 of the width, divided by 1.2.
		double tanH = tan(CameraFOV / 2);
		double tanV = tanH * 0.75 / 1.2;

		double worst = 0;
		static const double heights[] = { 0.05, 0.5, 0.95 };
		for (int i = 0; i < 3; i++)
		{
			Vector3 p = mo.pos + (0, 0, mo.Height * heights[i]);
			double x, y, depth;
			[x, y, depth] = ToView(p);
			if (depth < 16) return 0;
			// Allow for the actor's width at the sides.
			x = (abs(x) + mo.radius) / depth / tanH;
			y = abs(y) / depth / tanV;
			worst = max(worst, max(x, y));
		}
		if (worst > 1.0) return 0;
		if (!ClearLineTo(mo.pos + (0, 0, mo.Height * 0.5))) return 0;
		return 1.0 - worst;
	}

	// Is there no wall, floor or ceiling between the camera and this point?
	// (Things like candelabras don't count.)
	bool ClearLineTo(Vector3 p)
	{
		Vector3 d = p - pos;
		double dist = d.Length();
		return !LineTrace(VectorAngle(d.x, d.y), dist, -VectorAngle(d.xy.Length(), d.z), TRF_THRUACTORS);
	}

	// Where a point sits relative to the camera: sideways, up/down, and how
	// far in front.
	double, double, double ToView(Vector3 p)
	{
		Vector3 d = p - pos;
		double fwd  =  d.x * cos(Angle) + d.y * sin(Angle);
		double side = -d.x * sin(Angle) + d.y * cos(Angle);
		double depth = fwd * cos(Pitch) - d.z * sin(Pitch);
		double up    = fwd * sin(Pitch) + d.z * cos(Pitch);
		return side, up, depth;
	}
}

class RECameraHandler : EventHandler
{
	Array<REFixedCamera> cameras;

	// One entry per switch zone. Corners are stored 4 at a time.
	Array<int> zoneFrom;
	Array<int> zoneTo;
	Array<double> zoneX;
	Array<double> zoneY;

	int currentCam;
	bool locked;    // RE1's camera lock (used during cutscenes); unused for now

	// Safety net: after this many tics out of view (~0.2 s), pick the camera
	// that shows the player best.
	const RESCUE_DELAY = 7;
	int hiddenTics;
	int rescues;    // how often the safety net was needed (should stay 0)
	bool wasFirstPerson;

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) return;   // cameras were saved along with the game
		LoadCameraFile();
		if (cameras.Size() == 0) BuildAutoCameras();   // AutoCamera.zs
	}

	override void WorldTick()
	{
		PlayerPawn pmo = null;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (playeringame[i] && players[i].mo != null)
			{
				pmo = players[i].mo;
				break;
			}
		}
		if (pmo == null) return;

		// First-person view (V, RE_View.zs): look through Jill's eyes. When
		// she switches back, pick the best fixed camera for where she is now.
		let jill = RETankPlayer(pmo);
		if (jill != null && jill.bREFirstPerson)
		{
			if (pmo.player.camera != pmo) pmo.player.camera = pmo;
			wasFirstPerson = true;
			return;
		}
		if (wasFirstPerson)
		{
			wasFirstPerson = false;
			autoCand = -1;
			let best = BestCamera(pmo);
			if (best != null) SwitchTo(best.camId);
		}

		if (autoMode)
		{
			AutoTick(pmo);
			return;
		}
		if (cameras.Size() == 0) return;

		// RE1 check_camera_switch: only zones of the current camera count.
		if (!locked)
		{
			let current = FindCamera(currentCam);
			bool currentSees = current != null && current.ViewScore(pmo) > 0;
			for (int z = 0; z < zoneFrom.Size(); z++)
			{
				if (zoneFrom[z] != currentCam) continue;
				if (!PointInZone(z, pmo.pos.xy)) continue;

				// Never cut away from a view that shows the player to one
				// that doesn't.
				let target = FindCamera(zoneTo[z]);
				if (currentSees && (target == null || target.ViewScore(pmo) <= 0)) continue;

				SwitchTo(zoneTo[z]);
				break;
			}

			// Safety net: if the player has been out of view for a moment
			// (off screen or behind a wall), cut to the camera that shows
			// them best.
			let active = FindCamera(currentCam);
			if (active != null && active.ViewScore(pmo) > 0)
			{
				hiddenTics = 0;
			}
			else if (++hiddenTics >= RESCUE_DELAY)
			{
				let best = BestCamera(pmo);
				if (best != null)
				{
					rescues++;
					if (re_debugcams) Console.Printf("player out of view - rescue");
					SwitchTo(best.camId);
				}
				hiddenTics = 0;
			}
		}

		let cam = FindCamera(currentCam);
		if (cam == null) return;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (playeringame[i] && players[i].camera != cam)
			{
				players[i].camera = cam;
			}
		}
	}

	void SwitchTo(int id)
	{
		currentCam = id;
		if (re_debugcams) Console.Printf("camera %d", id);
	}

	REFixedCamera BestCamera(Actor mo)
	{
		REFixedCamera best = null;
		double bestScore = 0;
		for (int i = 0; i < cameras.Size(); i++)
		{
			if (cameras[i] == null) continue;
			double s = cameras[i].ViewScore(mo);
			// Two characters: prefer a camera that also shows the AI partner.
			let partner = REPartner.Find();
			if (s > 0 && partner != null) s += 0.5 * cameras[i].ViewScore(partner);
			if (s > bestScore)
			{
				best = cameras[i];
				bestScore = s;
			}
		}
		return best;
	}

	REFixedCamera FindCamera(int id)
	{
		for (int i = 0; i < cameras.Size(); i++)
		{
			if (cameras[i] != null && cameras[i].camId == id) return cameras[i];
		}
		return null;
	}

	// Is the point inside zone z? RE1 checks the 4 edges with cross products
	// (is_entity_in_switch_zone); this does the same and accepts the corners
	// in either clockwise or counter-clockwise order.
	bool PointInZone(int z, Vector2 p)
	{
		int side = 0;
		for (int k = 0; k < 4; k++)
		{
			int a = z * 4 + k;
			int b = z * 4 + (k + 1) % 4;
			double edge = (zoneX[b] - zoneX[a]) * (p.y - zoneY[a])
				- (zoneY[b] - zoneY[a]) * (p.x - zoneX[a]);
			if (edge > 0)
			{
				if (side < 0) return false;
				side = 1;
			}
			else if (edge < 0)
			{
				if (side > 0) return false;
				side = -1;
			}
		}
		return true;
	}

	// -----------------------------------------------------------------------
	// Reading mod/recams.txt
	// -----------------------------------------------------------------------

	void LoadCameraFile()
	{
		int lump = Wads.CheckNumForFullName("recams.txt");
		if (lump < 0)
		{
			Console.Printf("Resident Doom: recams.txt not found, no fixed cameras.");
			return;
		}

		String mapName = Level.MapName.MakeUpper();
		Array<String> lines;
		String text = Wads.ReadLump(lump);
		text.Split(lines, "\n");

		bool inMap = false;
		int startCam = -1;
		for (int i = 0; i < lines.Size(); i++)
		{
			String line = lines[i];
			int comment = line.IndexOf("//");
			if (comment >= 0) line = line.Left(comment);
			line.Substitute("\t", " ");
			line.Substitute("\r", "");

			Array<String> t;
			line.Split(t, " ", TOK_SKIPEMPTY);
			if (t.Size() == 0) continue;

			String word = t[0].MakeLower();
			if (word == "map")
			{
				inMap = t.Size() > 1 && t[1].MakeUpper() == mapName;
				continue;
			}
			if (!inMap) continue;

			if (word == "start" && t.Size() >= 2)
			{
				startCam = t[1].ToInt();
			}
			else if (word == "camera" && t.Size() >= 9)
			{
				AddCamera(t[1].ToInt(),
					(t[2].ToDouble(), t[3].ToDouble(), t[4].ToDouble()),
					(t[5].ToDouble(), t[6].ToDouble(), t[7].ToDouble()),
					t[8].ToDouble());
			}
			else if (word == "zone" && t.Size() >= 11)
			{
				zoneFrom.Push(t[1].ToInt());
				zoneTo.Push(t[2].ToInt());
				for (int k = 0; k < 4; k++)
				{
					zoneX.Push(t[3 + k * 2].ToDouble());
					zoneY.Push(t[4 + k * 2].ToDouble());
				}
			}
			else
			{
				Console.Printf("recams.txt line %d: can't read this line: %s", i + 1, lines[i]);
			}
		}

		if (startCam < 0 && cameras.Size() > 0) startCam = cameras[0].camId;
		currentCam = startCam;
	}

	void AddCamera(int id, Vector3 from, Vector3 lookAt, double fov)
	{
		let cam = REFixedCamera(Actor.Spawn("REFixedCamera", from));
		if (cam == null) return;
		cam.camId = id;
		cam.CameraFOV = fov;
		cam.LookAt(lookAt);
		cameras.Push(cam);
	}
}
