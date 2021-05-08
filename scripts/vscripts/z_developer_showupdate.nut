/*****************************************************************************
**  SHOW UPDATE DEMO  ( DEVELOPER MODE ONLY )
**
**  File "anv_mapfixes.nut" will have already explained "script ShowUpdate()"
**  with 'devchap( "TUTORIAL" )' if it's an Official Valve map -- Community maps
**  have no updates and do nothing. Everything here requires "developer 1" or 2
**  and manual running of HideUpdate() or ShowUpdate().
**
**  HideUpdate() deletes the Timer Think and clears all visual changes.
**
**  ShowUpdate() creates the Timer Think, displays a tutorial regarding CLIP
**  (blocker) color coding which correspond with "r_drawclipbrushes 2" or 1,
**  then draws all new blockers and glows new props. Also useful to force a
**  re-catalog of any created/deleted "anv_mapfixes"-prefixed entities.
**
**  DebugRedraw() is only called programmatically and isn't manual like the
**  others. It loops through all "anv_mapfixes"-prefixed blockers and props
**  and uses DebugDrawBox() or "StartGlowing" on them accordingly, also drawing
**  their names as overlays with DebugDrawText(). DebugDrawText() has a couple
**  limitations: (1) "useViewCheck" parameter as "false" is the best setting
**  as it draws multiple names and through walls whereas "true" is singular
**  names not through walls; (2) even when "false" it only draws text of origins
**  in view which is the reason DebugRedraw() exists to constantly refresh it
**  to support tester movement; and (3) it has been confirmed on four machines
**  to never draw text if equal or greater than 9487 units away from testers.
**  Redrawing wouldn't be required if it were DebugDrawBox() alone, but doing
**  so empowers us with some "WYSIWYG" editing.
**
**  For those using this function in-game be aware that blockers you create
**  manually will have their DebugDrawBox's persist round transition but the
**  actual entity itself won't.
**
**  Note that "angles" should be used sparingly because DebugDrawBoxDirection()
**  only supports ForwardVector Y/yaw -- it won't represent X/pitch and Z/roll.
**  Kerry added DebugDrawBoxAngles() to use instead but rotated clips always
**  block Physics so they're still visually identified for evaluation.
**
**  All of this is strictly opt-in and manual because while redrawing doesn't
**  cause flickering on DebugDrawBox()'s, if "nav_edit 1" or "director_debug 1"
**  is in use those tools will flicker every 1 second. Draws are client-side
**  where even if it's your own server it takes ~7 seconds to exist where draws
**  before then will be missed -- but not if it's manual!
*****************************************************************************/

// Call to cease and desist DebugRedraw(). Technically fires "StopGlowing" to all blockers,
// too, but only props will process that Input and it's more efficient than another loop.

function HideUpdate()
{
	EntFire( "anv_mapfixes_DebugRedraw_timer", "Kill" );

	// Fail-safe 2nd DebugDrawClear to resolve a rare use timing of it not clearing.

	DebugDrawClear();
	EntFire( "worldspawn", "RunScriptCode", "DebugDrawClear()", 0.1 );
	EntFire( g_UpdateName + "*", "StopGlowing" );
	
	// Disable glowing on any prop highlighted by ShowUpdate
	if ( g_TutorialShown )
	{
		for ( local index = 0;
			  g_arrayFixHandles[index] != null && index <= g_arrayFixHandles.len();
			  index++ )
		{
			EntFire( g_arrayFixHandles[index].GetName(), "StopGlowing" );
		}
	}
}

// Opacity override for DebugDrawBox's (default 37).

g_BoxOpacity <- 37;

// Only show CLIP (blocker) color coding tutorial once per load session.

g_TutorialShown <- false;

// Call to create a logic_timer as 1/10th of a Think to start DebugRedraw(). This Timer
// is named "anv_mapfixes_DebugRedraw_timer" and only exists if it's manually created.

function ShowUpdate( showType = "anv" )
{
	
	// Print a quick tutorial to console for CLIP (blocker) color coding and binds.

	if ( ! g_TutorialShown )
	{
		printl( "\nSHOW UPDATE DEMO MODE" );
		printl( "_____________________" );
		printl( "\nCLIP (blocker) color coding:\n" );
		printl( "\tRED\t\tEveryone" );
		printl( "\tPINK\t\tSurvivors" );
		printl( "\tGREEN\t\tSI Players" );
		printl( "\tBLUE\t\tSI Players and AI" );
		printl( "\tLT BLUE\t\tAll and Physics" );
		printl( "\nOther color coding:\n" );
		printl( "\tLT GREEN\tBrush (blocks LOS & hitreg)" );
		printl( "\tORANGE\t\tNavigation blocked" );
		printl( "\tYELLOW\t\tTrigger volume" );
		printl( "\tWHITE\t\tInfected ladder clone" );
		printl( "\tBLACK\t\tLump and _commentary.txt blockers" );
		printl( "\nDrawn boxes marked \"ANGLED\" unpreventably block Physics." );
		printl( "Adjust box opacity with \"script g_BoxOpacity = #\" (0-255)." );
		printl( "\nUse \"r_drawclipbrushes 2\" or 1 to see BSP-baked brushes." );
		printl( "\nRecommended tester binds:\n" );
		printl( "\tbind [ \"script ShowUpdate(); r_drawclipbrushes 2\"" );
		printl( "\tbind ] \"script HideUpdate(); r_drawclipbrushes 0\"" );
		printl( "\nRecommended \"map mapname versus\" test environment:\n" );
		printl( "\t\"jointeam 2; sb_all_bot_game 1; sb_stop 1; god 1; director_stop\"" );
		printl( "\nExit with \"script HideUpdate()\" (if used with nav_edit and" );
		printl( "director_debug this also stops their flickering). If you use" );
		printl( "a make_ function, run ShowUpdate() again to apply changes.\n" );

		g_TutorialShown = true;
	}

	// Catalog all "anv_mapfixes"-prefixed entities by populating a Handle array.
	// The "find" returns the earliest character index where 0 means it's a match.
	// The Timer (and any "helper entities") have no reason to be in this array.

	// Initialize arrays
	g_arrayFixHandles <- array( 1, null );
	g_arrayLadderSources <- array( 1, null);

	local entity = Entities.First();		// Start looping from "worldspawn".

	local index = 0;				// Increment not on loop but rather confirmed matches.

	while( ( entity = Entities.Next( entity ) ) != null )
	{
		// Clear glows from models
		EntFire( entity.GetName(), "StopGlowing" );
		
		// Determine which entities to index based on user input
		// all: All entities, regardless of targetname
		// anv: All "anv_mapfixes" prefixed entities - Omitting an argument will default to all
		// other: All non-"anv_mapfixes", i.e. lump files, commentary.txt, Meta/SourceMod, etc
		// default: Invalid argument provided, defaults to "anv"
		local strClassname = entity.GetClassname();
		local updateNamedEntity = entity.GetName().find( g_UpdateName ); // Returns 0 if string is found at start of name
		local validEntity = 0;
		
		showType = showType.tolower();
		
		switch( showType )
		{
			case "all":
				validEntity = 1;
				break;
			case "other":
				if ( updateNamedEntity == null )
				{
					validEntity = 1;
				}
				break;
			default:
				// case "anv"
				if ( updateNamedEntity == 0 )
				{
					validEntity = 1;
				}
				break;
		}
		
		if ( validEntity == 1 && entity.GetName() != "anv_mapfixes_DebugRedraw_timer" )
		{
			// Confirmed to be a fix entity so add it to array.
			
			g_arrayFixHandles[index] = entity;
			
			index++;
			
			// Resize array for next entity
			g_arrayFixHandles.resize( index + 1 , null );
		}
	}

	// Timer that DebugRedraw()'s every 1 second, better than AddThinkToEnt() because it
	// runs 1/10th as often and still looks good. Only make if one doesn't already exist.

	if ( Entities.FindByName( null, "anv_mapfixes_DebugRedraw_timer" ) == null )
	{
		SpawnEntityFromTable( "logic_timer",
		{
			targetname	=	"anv_mapfixes_DebugRedraw_timer",
			RefireTime	=	1,
			connections =
			{
				OnTimer =
				{
					cmd1 = "worldspawnCallScriptFunctionDebugRedraw0-1"
				}
			}
		} );
	}
}

// Declare function that houses the redraw loop the above Timer runs every 1 second.
// The IsValid() avoids "Accessed null instance" error if an entity within Handle array
// is deleted -- this will still break redraws, hence "TUTORIAL" to explain Hide/Show toggle.

function DebugRedraw()
{
	local index = 0;
	
	// Remove invalid or deleted entities from array before drawing
	for ( index = 0;
	      g_arrayFixHandles[index] != null && index <= g_arrayFixHandles.len();
	      index++ )
	{
		// Check if entity is valid
		if ( !g_arrayFixHandles[index].IsValid() )
		{
			// Entity is not valid, remove from array and resize
			g_arrayFixHandles.remove( index );
			printl( "Invalid entity removed at index: " + index );
		}
	}
	
	// Clear ladder model sources array at the start of a redraw
	g_arrayLadderSources.clear()
	
	// Draw all indexed entities.

	for ( index = 0;
	      g_arrayFixHandles[index] != null && g_arrayFixHandles[index].IsValid();
	      index++ )
	{
		
		// Only clear for 1st redrawn entity. If absent, only last-most blocker is drawn.
		// Props don't need to be "redrawn" since the one "StartGlowing" is sufficient.

		if ( index == 0 )
		{
			DebugDrawClear();
		}

		// Variables for readability. GetOrigin() and GetName() read well without them.

		local strClassname = g_arrayFixHandles[index].GetClassname();
		local hndFixHandle = g_arrayFixHandles[index];
		
		// Clear glows from models
		EntFire( hndFixHandle.GetName(), "StopGlowing" );

		// Restore Keyvalues from make_clip() to draw visible box for invisible blocker.

		if ( strClassname == "env_physics_blocker" || strClassname == "env_player_blocker" )
		{
			local intBlockType = NetProps.GetPropInt( hndFixHandle, "m_nBlockType" );
			
			// See SetShow function
			switch( g_SetShowClip )
			{
				case 0:
					continue;
					break;
				case 1:
					break;
				case 2:
					if ( strClassname == "env_player_blocker" ) continue;
					break;
				case 3:
					if ( strClassname == "env_physics_blocker" ) continue;
					break;
			}
			
			if ( g_SetShowClipBlock != -1 )
			{
				if ( g_SetShowClipBlock != intBlockType ) continue;
			}

			local vecBoxColor = null;

			switch( intBlockType )
			{
				case 0:	vecBoxColor = Vector( 255,   0,   0 );	break;	// "Everyone" (RED)
				case 1:	vecBoxColor = Vector( 185,   0, 185 );	break;	// "Survivors" (PINK)
				case 2:	vecBoxColor = Vector(   0, 255,   0 );	break;	// "SI Players" (GREEN)
				case 3:	vecBoxColor = Vector(   0,   0, 255 );	break;	// "SI Players and AI" (BLUE)
				case 4:	vecBoxColor = Vector(   0, 128, 255 );	break;	// "All and Physics" (LT BLUE)
				default: vecBoxColor = Vector(  0,   0,   0 );	break;	// Block type not specified (BLACK)
			}

			local vecMins = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMins" );
			local vecMaxs = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMaxs" );

			// Note DebugDrawBoxDirection() with GetForwardVector() only supports Y (yaw).
			// X/pitch and Z/roll don't show. Kerry added DebugDrawBoxAngles() to fix this.
			// DebugDrawBoxAngles() requires a QAngle which GetAngles() returns!

			DebugDrawBoxAngles( hndFixHandle.GetOrigin(), vecMins, vecMaxs,
					    hndFixHandle.GetAngles(), vecBoxColor,
					    g_BoxOpacity, 99999999 );

			// Post-fix " (ANGLED)" to all blockers that have non-"0 0 0" rotation. This is
			// warned in ShowUpdate()'s tutorial. Engine forces rotated clips to block Physics!
			// NetProp "m_angRotation" used instead of GetAngles() because it returns a Vector.

			local strPseudonym = hndFixHandle.GetName();

			if ( NetProps.GetPropVector( hndFixHandle, "m_angRotation" ).tostring() != Vector( 0, 0, 0 ).tostring() )
			{
				strPseudonym = strPseudonym + " (ANGLED)";
			}
			
			// Pass clip type to name drawing function
			local clipType = "";
			switch( strClassname )
			{
				case "env_physics_blocker":	clipType =	"CLIP";  break;
				case "env_player_blocker":	clipType =	"PCLIP"; break;
			}

			// Draw text to identify entity
			DebugRedrawName( hndFixHandle.GetOrigin(), strPseudonym, clipType, index);
		}

		// Restore Keyvalues from make_brush() to draw visible box for invisible brush.

		if ( strClassname == "func_brush" )
		{
			
			// See SetShow function
			switch( g_SetShowBrush )
			{
				case 0:
					continue;
					break;
				case 1:
					// Check if a brush model is used, script-added entities won't have a model
					if ( NetProps.GetPropInt( hndFixHandle, "m_nModelIndex" ) != 0 ) continue;
					break;
				case 2:
					break;
			}
			
			local vecBoxColor = Vector( 108, 200, 64 );	// LT GREEN

			local vecMins = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMins" );
			local vecMaxs = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMaxs" );

			// Brush rotation unsupported so GetAngles() does nothing.

			DebugDrawBoxAngles( hndFixHandle.GetOrigin(), vecMins, vecMaxs,
					    hndFixHandle.GetAngles(), vecBoxColor,
					    g_BoxOpacity, 99999999 );

			// Draw text to identify entity
			DebugRedrawName( hndFixHandle.GetOrigin(), hndFixHandle.GetName(), "BRUSH", index);
		}

		// Restore Keyvalues from make_navblock() to draw visible box for navblocked region.

		if ( strClassname == "func_nav_blocker" )
		{
			// See SetShow function
			switch( g_SetShowNav )
			{
				case 0:
					continue;
					break;
				case 1:
					// Check if a brush model is used, script-added entities won't have a model
					if ( NetProps.GetPropInt( hndFixHandle, "m_nModelIndex" ) != 0 ) continue;
					break;
				case 2:
					break;
			}
			
			local vecBoxColor = Vector( 255, 45, 0 );	// ORANGE

			local vecMins = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMins" );
			local vecMaxs = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMaxs" );

			// Rotation on navblockers is especially unsupported and always 0's.

			DebugDrawBoxAngles( hndFixHandle.GetOrigin(), vecMins, vecMaxs,
					    hndFixHandle.GetAngles(), vecBoxColor,
					    g_BoxOpacity, 99999999 );

			// Draw text to identify entity
			DebugRedrawName( hndFixHandle.GetOrigin(), hndFixHandle.GetName(), "NAVBLOCK", index);
		}

		// Restore Keyvalues from several "trigger_" entities to draw visible boxes for them.

		if ( strClassname == "trigger_multiple"
		  || strClassname == "trigger_once"
		  || strClassname == "trigger_push"
		  || strClassname == "trigger_hurt"
		  || strClassname == "trigger_hurt_ghost"
		  || strClassname == "trigger_auto_crouch"
		  || strClassname == "trigger_playermovement"
		  || strClassname == "trigger_teleport" )
		{
			// See SetShow function
			switch( g_SetShowTrigger )
			{
				case 0:
					continue;
					break;
				case 1:
					// Check if a brush model is used, script-added entities won't have a model
					if ( NetProps.GetPropInt( hndFixHandle, "m_nModelIndex" ) != 0 ) continue;
					break;
				case 2:
					break;
			}
			
			local vecBoxColor = Vector( 255, 255, 0 );	// YELLOW

			local vecMins = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMins" );
			local vecMaxs = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMaxs" );

			// Triggers are a wildcard but try to draw Angles just in case they're non-0.
			// Note that "trigger_push" rotation has unknown mild influence on Push Direction
			// that's only noticeable with Death Toll 5's Rockslide RNG. Angles definitely don't
			// impact actual collidability and is why "trigger_hurt" fails entirely with them.

			DebugDrawBoxAngles( hndFixHandle.GetOrigin(), vecMins, vecMaxs,
					    hndFixHandle.GetAngles(), vecBoxColor,
					    g_BoxOpacity, 99999999 );

			// Draw text to identify entity
			DebugRedrawName( hndFixHandle.GetOrigin(), hndFixHandle.GetName(), "TRIGGER", index);
		}

		// Extract vecMins/vecMaxs from make_ladder() to draw visible box around cloned Infected Ladder.

		if ( strClassname == "func_simpleladder" )
		{
			local vecMins = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMins" );
			local vecMaxs = NetProps.GetPropVector( hndFixHandle, "m_Collision.m_vecMaxs" );
			
			// Draw text at the SOURCE ladder's location for inspection/comparison.
			// For fun, sprinkle in its modelindex-turned-model so that it
			// can at least be compared with "developer 1" Table dumps!
			
			local modelName = hndFixHandle.GetModelName();
			
			// Check if model name is already being displayed
			if ( g_arrayLadderSources.find(modelName) == null )
			{
				DebugDrawText( vecMins, "LADDER CLONE SOURCE (" + modelName + ")", false, 99999999 );
				g_arrayLadderSources.resize( g_arrayLadderSources.len() + 1 , null );
				g_arrayLadderSources.append( modelName );
			}
			
			local vecBoxColor = Vector( 255, 255, 255 );	// WHITE
			
			// See SetShow function
			switch( g_SetShowLadder )
			{
				case 0:
					continue;
					break;
				case 1:
					// Check if origin is (0,0,0), script-added entities will not be at (0,0,0)
					// This will also highlight any ladders that have been moved
					if ( hndFixHandle.GetOrigin().x == 0 && hndFixHandle.GetOrigin().y == 0 && hndFixHandle.GetOrigin().z == 0 )
					{
						continue;
					}
					else
					{
						// Highlight moved non-update ladders in purple
						if ( hndFixHandle.GetName().find( g_UpdateName ) == null)
						{
							vecBoxColor = Vector( 134, 60, 218 );	// PURPLE
						}
					}
					break;
				case 2:
					break;
			}

			// By the grace of GabeN with a sparkle of luck from Kerry ladders can be rotated.

			// Salt the opacity with + 24 so it stands out a bit more.

			DebugDrawBoxAngles( hndFixHandle.GetOrigin(), vecMins, vecMaxs,
					    hndFixHandle.GetAngles(), vecBoxColor,
					    g_BoxOpacity + 24, 99999999 );

			// Calculate correct position of ladders to display text at, otherwise labels for rotated ladder brushes will be displaced
			// Position of ladder mins and maxs to transform
			local vectorX = ( vecMins.x + vecMaxs.x ) / 2;
			local vectorY = ( vecMins.y + vecMaxs.y ) / 2;
			local vectorZ = ( vecMins.z + vecMaxs.z ) / 2;
			// Angle ladder is rotated by in radians
			local angleX = ( hndFixHandle.GetAngles().z * PI ) / 180;
			local angleY = ( hndFixHandle.GetAngles().x * PI ) / 180;
			local angleZ = ( hndFixHandle.GetAngles().y * PI ) / 180;
			// Store trig calculations
			local cosX = cos( angleX );
			local cosY = cos( angleY );
			local cosZ = cos( angleZ );
			local sinX = sin( angleX );
			local sinY = sin( angleY );
			local sinZ = sin( angleZ );
			// Mid-calculation variables
			local transformedX = 0;
			local transformedY = 0;
			local transformedZ = 0;
			
			// 3D Rotation Matrix
			transformedY = ( cosX * vectorY ) - ( sinX * vectorZ );
			transformedZ = ( cosX * vectorZ ) + ( sinX * vectorY );
			vectorY = transformedY;
			vectorZ = transformedZ;
			
			transformedX = ( cosY * vectorX ) + ( sinY * vectorZ );
			transformedZ = ( cosY * vectorZ ) - ( sinY * vectorX );
			vectorX = transformedX;
			vectorZ = transformedZ;
			
			transformedX = ( cosZ * vectorX ) - ( sinZ * vectorY );
			transformedY = ( cosZ * vectorY ) + ( sinZ * vectorX );
			vectorX = transformedX;
			vectorY = transformedY;
			
			// Final result is the offset the ladder from the world's origin (0,0,0), but corrected for rotation
			// GetOrigin gives us the offset of the ladder from its cloned model
			// Adding them together produces the actual position of the ladder in the world
			local originAngleFix = Vector( vectorX, vectorY, vectorZ );
			
			// Draw text to identify entity
			DebugRedrawName( hndFixHandle.GetOrigin() + originAngleFix, hndFixHandle.GetName(), "LADDER", index);
		}

		// Keyvalues from make_prop() don't need restoration as attributes can be visually assessed.

		if ( strClassname == "prop_dynamic"
		  || strClassname == "prop_dynamic_override"
		  || strClassname == "prop_physics"
		  || strClassname == "prop_physics_override" )
		{
			// See SetShow function
			switch( g_SetShowProp )
			{
				case 0:
					EntFire( hndFixHandle.GetName(), "StopGlowing" );
					continue;
					break;
				case 1:
					break;
			}
			
			EntFire( hndFixHandle.GetName(), "StartGlowing" );

			// Draw text to identify entity
			DebugRedrawName( hndFixHandle.GetOrigin(), hndFixHandle.GetName(), "PROP", index);
		}
	}
}

function DebugRedrawName(origin, name, entityType, index)
{
	// Determine distance from player to text - Too expensive to do within drawing of each name, needs a better solution
	//local playerDistance = null;
	//if ( Entities.FindByClassnameWithin( playerDistance, "player", origin, g_TextCullRange) == null )
	//{
	//	return;
	//}
	
	local namePrefix = entityType + ": ";
	local additionalPrefix = ""
	local drawName = "";
	
	// Rules by entity type
	switch( entityType )
	{
		case "CLIP":
			// Prefix for non-anv_mapfixes entities
			additionalPrefix = "(LUMP)"
			break;
		case "PCLIP":
			// Prefix for commentary blocker entities (env_player_blocker)
			additionalPrefix = "(COMMENTARY)"
			break;
		default:
			break;
	}
	
	if ( name == "" )
	{
		name = "unnamed";
	}
	
	// Build display text and check for g_UpdateName string within entity name
	if ( name.find( g_UpdateName ) == null )
	{
		// g_UpdateName was not found, mark as non-anv_mapfixes entity
		namePrefix = additionalPrefix + " " + namePrefix;
	}
	else
	{
		// g_UpdateName string was found, remove it
		name = name.slice( g_UpdateName.len(), name.len() );
	}
	
	drawName = namePrefix + name + " (" + index + ")";
	
	DebugDrawText( origin, drawName, false, 99999999 );
}

// Initialize SetShow settings
g_SetShowClip <- 1;
g_SetShowClipBlock <- -1;
g_SetShowBrush <- 1;
g_SetShowNav <- 1;
g_SetShowTrigger <- 1;
g_SetShowLadder <- 1;
g_SetShowProp <- 1;

function SetShow( entityGroup = null, value = null )
{
	/*
	** Entity Groups:
	** all
	**		- Entities:	All below entities
	**		- Values:	0 = Hides all entity groups, 1 = Shows all entity groups (Default)
	** clip
	** 		- Entities:	env_physics_blocker, env_player_blocker
	**		- Values:	0 = Hide all clips, 1 = Show all clips (Default), 2 = Only env_physics_blocker, 3 = Only env_player_blocker
	** clipblock
	**		- Entities:	env_physics_blocker, env_player_blocker - Filters by BlockType key value
	**		- Values:	all (-1) = All block types (Default), 0 = Everyone, 1 = Survivors, 2 = Player Infected,
	**					3 = All Special Infected (Player and AI), 4 = All players and physics objects (env_physics_blocker only)
	** brush
	** 		- Entities:	func_brush
	**		- Values:	0 = Hide all brushes, 1 = Show all brushes with "model" key value set to "0" (Default), 2 = Shows all brushes
	** nav
	** 		- Entities:	func_nav_blocker
	**		- Values:	0 = Hide all nav blockers, 1 = Show all nav blockers with "model" key value set to "0" (Default), 2 = Shows all nav blockers
	** trigger
	** 		- Entities:	trigger_multiple, trigger_once, trigger_push, trigger_hurt, trigger_hurt_ghost, trigger_auto_crouch,
	**					trigger_playermovement, trigger_teleport
	**		- Values:	0 = Hide all triggers, 1 = Show all triggers with "model" key value set to "0" (Default), 2 = Shows all triggers
	** ladder
	** 		- Entities:	func_simpleladders
	**		- Values:	0 = Hide all ladders, 1 = Show all ladders with non-zero "origin" key value (Default), 2 = Shows all ladders
	** prop
	** 		- Entities:	prop_dynamic, prop_dynamic_override, prop_physics, prop_physics_override
	**		- Values:	0 = Hide all props, 1 = Shows all props (Default)
	*/
	
	entityGroup = entityGroup.tolower();
	
	// Process value to ensure it's valid for the entityGroup switch
	switch( value )
	{
		case null:
			if ( entityGroup == "clipblock" )
			{
				value = -1;
			}
			else
			{
				value = 1;
			}
			break;
		case "all":
			value = -1;
			break;
		default:
			try
			{
				value = value.tointeger();
			}
			catch ( err )
			{
				value = 1;
				printl("\nValue: '" + value + "' is not valid, defaulting to 1\n");
			}
			break;
	}
	
	switch( entityGroup )
	{
		case "all":
			if (value < 0 || value > 1)
			{
				value = 1;
			}
			g_SetShowClip <- value;
			if ( value == 1 )
			{
				g_SetShowClipBlock <- -1;
			}
			else
			{
				g_SetShowClipBlock <- value;
			}
			g_SetShowBrush <- value;
			g_SetShowNav <- value;
			g_SetShowTrigger <- value;
			g_SetShowLadder <- value;
			g_SetShowProp <- value;
			break;
		case "clip":
			if (value < 0 || value > 3)
			{
				value = 1;
			}
			g_SetShowClip <- value;
			break;
		case "clipblock":
			if (value < -1 || value > 4)
			{
				value = -1;
			}
			g_SetShowClipBlock <- value;
			break;
		case "brush":
			if (value < 0 || value > 2)
			{
				value = 1;
			}
			g_SetShowBrush <- value;
			break;
		case "nav":
			if (value < 0 || value > 2)
			{
				value = 1;
			}
			g_SetShowNav <- value;
			break;
		case "trigger":
			if (value < 0 || value > 2)
			{
				value = 1;
			}
			g_SetShowTrigger <- value;
			break;
		case "ladder":
			if (value < 0 || value > 2)
			{
				value = 1;
			}
			g_SetShowLadder <- value;
			break;
		case "prop":
			if (value < 0 || value > 1)
			{
				value = 1;
			}
			g_SetShowProp <- value;
			break;
		default:
			printl("\nEntity group: '" + entityGroup + "' is not valid, or no entity group was specified\n");
			return;
			break;
	}
	
	printl("\nShowing Group: '" + entityGroup + "', with filter: '" + value + "'.\n");
}
