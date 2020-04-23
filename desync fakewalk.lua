-- [x]============================[ UI References ]============================[x]
local limit = ui.reference( "AA", "Fake lag", "Limit" )
local variance = ui.reference( "AA", "Fake lag", "Variance" )
local slowmotion, slowmotion_state = ui.reference( "AA", "Other", "Slow motion" )
local fake_limit = ui.reference( "AA", "Anti-aimbot angles", "Fake yaw limit" )
local onshot = ui.reference( "AA", "Other", "On shot anti-aim" )

-- [x]================================================[ UI Additions ]================================================[x]
local fakewalk_mode = ui.new_combobox( "AA", "Anti-aimbot angles", "Fakewalk mode", { "Opposite", "Extend", "Jitter" } )

-- [x]============[ Data Structures ]============[x]
local function vec_3( _x, _y, _z ) 
	return { x = _x or 0, y = _y or 0, z = _z or 0 } 
end

-- [x]================================================[ Math Functions ]================================================[x]
local function deg_to_rad( val ) 
	return val * ( math.pi / 180. )
end

local function vector_to_angles( forward, angles )
	if forward.x == 0 and forward.y == 0 then
		if forward.z > 0 then
			angles.x = -90
		else
			angles.x = 90
		end
		angles.y = 0
	else
		angles.x = math.atan2( -forward.z, math.sqrt( forward.x * forward.x + forward.y * forward.y ) ) * ( 180 / math.pi )
		angles.y = math.atan2( forward.y, forward.x ) * ( 180 / math.pi )
	end

	angles.z = 0
end

local function angle_to_vector( angles, forward )
	local sp = math.sin( deg_to_rad( angles.x ) )
	local cp = math.cos( deg_to_rad( angles.x ) )
	local sy = math.sin( deg_to_rad( angles.y ) )
	local cy = math.cos( deg_to_rad( angles.y ) )

	forward.x = cp * cy
	forward.y = cp * sy
	forward.z = -sp
end

function round( x ) -- https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
    return x >= 0 and math.floor( x+0.5 ) or math.ceil( x-0.5 )
end

local function normalize_as_yaw( yaw )
	if yaw > 180 or yaw < -180 then
		local revolutions = round( math.abs( yaw / 360 ) )

		if yaw < 0 then
			yaw = yaw + 360 * revolutions
		else
			yaw = yaw - 360 * revolutions
		end
	end

	return yaw
end

-- [x]======================================[ Local Functions ]======================================[x]
local function quick_stop( cmd )
	local velocity_prop = vec_3( entity.get_prop( entity.get_local_player( ), "m_vecVelocity" ) )
	local velocity = math.sqrt( velocity_prop.x * velocity_prop.x + velocity_prop.y * velocity_prop.y )
	local direction = vec_3( 0, 0, 0 )
	vector_to_angles( velocity_prop, direction )
	direction.y = cmd.yaw - direction.y;

	local new_move = vec_3( 0, 0, 0 )
	angle_to_vector( direction, new_move );
	local max_move = math.max( math.abs( cmd.forwardmove ), math.abs( cmd.sidemove ) )
	local multiplier = 450 / max_move
	new_move = vec_3( new_move.x * -multiplier, new_move.y * -multiplier, new_move.z * -multiplier )

	cmd.forwardmove = new_move.x
	cmd.sidemove = new_move.y
end

local equiped_type = 0
local equiped_name = ""
local function get_flick_tick( )
	local weapon = entity.get_player_weapon( entity.get_local_player( ) )
	local scoped = entity.get_prop( entity.get_local_player( ), "m_bIsScoped" )

	if ( equiped_name == "scar20" 
		or equiped_name == "g3sg1"
		or equiped_name == "sg556"
		or equiped_name == "aug" )
		and scoped == 1 then
		return 10	
	end

	if equiped_name == "awp"
		or equiped_name == "m249" then
		return 7
	end
	
	if equiped_name == "negev" then
		return 9
	end
	
	if equiped_type == 5
		or equiped_type == 4
		or equiped_type == 3 
		or equiped_name == "deagle" then
		return 6
	end
	
	return 5
end

-- [x]======================================[ Callbacks ]======================================[x]
local fakewalking = false
local stored_onshot = false
local stored_limit = 0
local flicks = 0
client.set_event_callback( "setup_command", function( cmd )	
	if ui.get( variance ) > 0 or ui.get( slowmotion ) then
		return
	end	
	
	if not ui.get( slowmotion_state ) then
		if fakewalking then
			ui.set( onshot, stored_onshot )
			ui.set( limit, stored_limit )
		end
		stored_onshot = ui.get( onshot )
		stored_limit = ui.get( limit )
		fakewalking = false
		return
	end
	
	-- Setup angles
	local eye_angles = vec_3( entity.get_prop( entity.get_local_player( ), "m_angEyeAngles" ) )
	local real_angles = vec_3( entity.get_prop( entity.get_local_player( ), "m_angAbsRotation" ) )
	local fake_side = ( normalize_as_yaw( real_angles.y - eye_angles.y ) > 0 ) and -1 or 1
	
	cmd.allow_send_packet = false
	fakewalking = true
	ui.set( onshot, false )
	ui.set( limit, 14 )
	if cmd.chokedcommands >= ( ui.get( limit ) - 11 ) then 
		if cmd.forwardmove ~= 0 or cmd.sidemove ~= 0 then
			quick_stop( cmd )
		end
	end

	local flick_tick = get_flick_tick( )
	if cmd.chokedcommands == ( ui.get( limit ) - flick_tick ) then
		flicks = flicks + 1
		if ui.get( fakewalk_mode ) == "Opposite" then
			cmd.yaw = normalize_as_yaw( eye_angles.y + ( 60 * fake_side ) )
		elseif ui.get( fakewalk_mode ) == "Extend" then
			cmd.yaw = normalize_as_yaw( eye_angles.y + ( 90 * fake_side ) )
		elseif ui.get( fakewalk_mode ) == "Jitter" then
			cmd.yaw = normalize_as_yaw( eye_angles.y + ( 60 * ( flicks % 2 == 0 and -1 or 1 ) ) )
		end
	end
end )

client.set_event_callback( "item_equip", function( event_data )
	equiped_name = event_data.item
	equiped_type = event_data.weptype
end )

client.set_event_callback( "paint", function( )
	ui.set_visible( fakewalk_mode, not ui.get( slowmotion ) and true or false )
end )