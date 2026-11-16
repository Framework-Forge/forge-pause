ForgeMap = {}
local camera, origin, target, distance, heading
local sessionToken, sequence = nil, 0
local returningToken,returningTicket
local clearReady = false
local pitch=57.1
local pose
local function damagedGlassNearby()
    local p=GetEntityCoords(PlayerPedId())
    for _,vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local v=GetEntityCoords(vehicle)
            if (v.x-p.x)^2+(v.y-p.y)^2+(v.z-p.z)^2<=80.0^2 then
                for window=0,3 do
                    if not IsVehicleWindowIntact(vehicle,window) then return true end
                end
            end
        end
    end
    return false
end
local function project(x,y,z)
    if not pose then return false end
    local dx,dy,dz=x-pose.x,y-pose.y,z-pose.z
    local depth=dx*pose.fx+dy*pose.fy+dz*pose.fz
    if depth<1.0 then return false end
    local tangent=math.tan(math.rad(25.0))
    local sx=0.5+(dx*pose.rx+dy*pose.ry)/(2*depth*tangent*GetAspectRatio(false))
    local sy=0.5-(dx*pose.ux+dy*pose.uy+dz*pose.uz)/(2*depth*tangent)
    return true,sx,sy
end
local function clearView()
    if not clearReady then
        CreateTimecycleModifier('forge_pause_map_clear')
        for key, value in pairs({ fog_start=10000.0, fog_density=0.0, fog_falloff=0.0, fog_base_height=0.0, far_clip=50000.0 }) do
            SetTimecycleModifierVar('forge_pause_map_clear', key, value, value)
        end
        clearReady = true
    end
    SetTimecycleModifier('forge_pause_map_clear')
    SetTimecycleModifierStrength(1.0)
    if SetFogVolumeRenderDisabled then SetFogVolumeRenderDisabled(true) end
end

local function update()
    local angle = math.rad(heading)
    local radius = distance * math.cos(math.rad(pitch))
    local x,y,z=target.x+math.sin(angle)*radius,target.y-math.cos(angle)*radius,target.z+distance*math.sin(math.rad(pitch))
    SetCamCoord(camera,x,y,z)
    local fx,fy,fz=target.x-x,target.y-y,target.z-z
    local length=math.sqrt(fx*fx+fy*fy+fz*fz);fx,fy,fz=fx/length,fy/length,fz/length
    local rightLength=math.sqrt(fx*fx+fy*fy)
    local rx,ry=fy/rightLength,-fx/rightLength
    pose={x=x,y=y,z=z,fx=fx,fy=fy,fz=fz,rx=rx,ry=ry,ux=ry*fz,uy=-rx*fz,uz=rx*fy-ry*fx}
    PointCamAtCoord(camera, target.x, target.y, target.z)
    SetFocusPosAndVel(target.x, target.y, target.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(target.x, target.y, target.z)
end

function ForgeMap.stop()
    if not camera then return end
    ClearFocus()
    local p=GetEntityCoords(PlayerPedId())
    RequestCollisionAtCoord(p.x,p.y,p.z)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(camera, false)
    camera = nil
    if PauseMapGround then PauseMapGround.reset() end
    pose=nil
    ForgeMap.route=nil
    SetMicrophonePosition(false,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)
    returningToken=sessionToken
    sessionToken=nil
    returningTicket=PauseEnvironment.stop()
    TriggerServerEvent('forge-pause:map:leave',returningToken)
    ClearFocus()
    ClearTimecycleModifier()
    if SetFogVolumeRenderDisabled then SetFogVolumeRenderDisabled(false) end
    TriggerEvent('forge-pause:restoreFilter')
end
RegisterNetEvent('forge-pause:map:restored',function(token)
    if source~=65535 or token~=returningToken or not returningTicket then return end
    PauseEnvironment.resync(returningTicket)
    returningToken,returningTicket=nil,nil
end)

function ForgeMap.start()
    if Config.Map.mode ~= '3d' or camera then return end
    returningToken,returningTicket=nil,nil
    origin = GetEntityCoords(PlayerPedId())
    target = { x = origin.x, y = origin.y, z = origin.z }
    distance = Config.Map.initialDistance
    heading = GetEntityHeading(PlayerPedId())
    pitch=57.1
    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(camera, 50.0)
    SetCamFarClip(camera, 60000.0)
    update()
    RenderScriptCams(true, false, 0, true, true)
    clearView()
    PauseEnvironment.start()
    sequence=sequence+1
    sessionToken=tostring(GetGameTimer())..':'..tostring(sequence)
    local token=sessionToken
    local preserveScene=damagedGlassNearby()
    CreateThread(function()
        local owned = camera
        local ok, result = pcall(pr_lib.callback.await, 'forge-pause:map:enter', 5000, token, preserveScene)
        if camera ~= owned or sessionToken~=token then TriggerServerEvent('forge-pause:map:leave',token) return end
        if not ok or not result or not result.ok then ForgeMap.stop() return end
        PauseEnvironment.tick()
    end)
    local owned = camera
    CreateThread(function()
        local nextClear, nextHeartbeat, nextProjection = 0, 0, 0
        while camera == owned do
            OverrideLodscaleThisFrame(1.6)
            local pedPosition=GetEntityCoords(PlayerPedId())
            SetMicrophonePosition(true,pedPosition.x,pedPosition.y,pedPosition.z,pedPosition.x,pedPosition.y,pedPosition.z,pedPosition.x,pedPosition.y,pedPosition.z)
            if GetGameTimer() >= nextClear then clearView() PauseEnvironment.tick() nextClear = GetGameTimer() + 1000 end
            if GetGameTimer() >= nextHeartbeat then TriggerServerEvent('forge-pause:map:heartbeat',token) nextHeartbeat = GetGameTimer()+5000 end
            if GetGameTimer() >= nextProjection then
                if PauseMapGround then PauseMapGround.tick() end
                local projected,zones={},{}
                for i,b in ipairs(ForgeMap.markers or {}) do
                    local ground
                    if PauseMapGround then ground=PauseMapGround.height(b) else ground=(b.z or 30)+0.15 end
                    local visible,x,y=false
                    if ground then visible,x,y=project(b.x,b.y,ground) end
                    if visible then projected[#projected+1]={id=i,x=x,y=y} end
                    local shape=b.zoneShape
                    if shape and shape.mode~='none' and shape.alpha>0 then
                        local vertices,allVisible={},true
                        local angle=math.rad(shape.rotation or 0)
                        local cosine,sine=math.cos(angle),math.sin(angle)
                        local count=shape.mode=='radius' and 32 or 4
                        for index=1,count do
                            local dx,dy
                            if shape.mode=='radius' then
                                local theta=(index-1)*2*math.pi/count;dx,dy=math.cos(theta)*shape.radius,math.sin(theta)*shape.radius
                            else dx=(index==1 or index==4) and -shape.width/2 or shape.width/2;dy=index<=2 and -shape.height/2 or shape.height/2 end
                            local vx,vy=b.x+dx*cosine-dy*sine,b.y+dx*sine+dy*cosine
                            local vz
                            if PauseMapGround then vz=PauseMapGround.height(b,vx,vy) else vz=ground end
                            local ok,sx,sy=false
                            if vz then ok,sx,sy=project(vx,vy,vz) end
                            if not ok then allVisible=false break end
                            vertices[#vertices+1]={x=sx,y=sy}
                        end
                        if allVisible then zones[#zones+1]={id=i,points=vertices,color=shape.color,alpha=shape.alpha} end
                    end
                end
                local route={}
                for _,p in ipairs(ForgeMap.route or {}) do
                    local visible,x,y=project(p.x,p.y,p.z+1.2)
                    route[#route+1]=visible and {x=x,y=y} or false
                end
                local visible,x,y=project(pedPosition.x,pedPosition.y,pedPosition.z+1.0)
                SendNUIMessage({action='mapProjection',points=projected,zones=zones,route=route,player=visible and {x=x,y=y} or false})
                nextProjection=GetGameTimer()+100
            end
            Wait(0)
        end
    end)
    -- Streaming follows the viewed region without moving the player.
end
function ForgeMap.fly(x,y)
    if not camera then return end
    target.x,target.y=x,y
    local ok,z=GetGroundZFor_3dCoord(x,y,1000.0,false)
    if ok then target.z=z end
    update()
end

function ForgeMap.move(data)
    if not camera then return end
    local dx = math.max(-1, math.min(1, tonumber(data.x) or 0))
    local dy = math.max(-1, math.min(1, tonumber(data.y) or 0))
    heading = heading + math.max(-20, math.min(20, tonumber(data.rotate) or 0))
    pitch=math.max(20,math.min(89,pitch+math.max(-15,math.min(15,tonumber(data.tilt) or 0))))
    distance = math.max(Config.Map.minDistance, math.min(Config.Map.maxDistance, distance * (1.15 ^ math.max(-4,math.min(4,tonumber(data.zoom) or 0)))))
    local angle = math.rad(heading)
    local mx = (dx * math.cos(angle) - dy * math.sin(angle)) * distance * 0.12
    local my = (dx * math.sin(angle) + dy * math.cos(angle)) * distance * 0.12
    target.x = math.max(-6000, math.min(6500, target.x + mx))
    target.y = math.max(-5000, math.min(10000, target.y + my))
    local ok, z = GetGroundZFor_3dCoord(target.x, target.y, 1000.0, false)
    if ok then target.z = z end
    update()
end

function ForgeMap.data()
    local p = GetEntityCoords(PlayerPedId())
    local result = { x = p.x, y = p.y, blips = PauseWorldRuntime and PauseWorldRuntime.mapPoints() or {} }
    if PauseMapAPI then for _,point in ipairs(PauseMapAPI.mapPoints()) do result.blips[#result.blips+1]=point end end
    for _,point in ipairs(result.blips) do
        local zone=GetLabelText(GetNameOfZone(point.x,point.y,point.z))
        point.zone=zone~='NULL' and zone or ''
    end
    for sprite = 0, 965 do
        local blip = GetFirstBlipInfoId(sprite)
        local count = 0
        while DoesBlipExist(blip) and count < 200 and #result.blips < 800 do
            local coords = GetBlipInfoIdCoord(blip)
            local managed=(PauseWorldRuntime and PauseWorldRuntime.describe(blip)) or (PauseMapAPI and PauseMapAPI.describe(blip))
            if not managed and GetBlipInfoIdDisplay(blip) ~= 0 and GetBlipAlpha(blip) > 0 then
                local zone=GetLabelText(GetNameOfZone(coords.x,coords.y,coords.z))
                result.blips[#result.blips + 1] = { x = coords.x, y = coords.y, z = coords.z, sprite = sprite, color = GetBlipColour(blip), zone=zone~='NULL' and zone or '' }
            end
            count = count + 1
            blip = GetNextBlipInfoId(sprite)
        end
    end
    local waypoint = GetFirstBlipInfoId(8)
    while DoesBlipExist(waypoint) and PauseWorldRuntime and PauseWorldRuntime.describe(waypoint) do
        waypoint=GetNextBlipInfoId(8)
    end
    if DoesBlipExist(waypoint) then
        local pos = GetBlipInfoIdCoord(waypoint)
        result.waypoint = { x = pos.x, y = pos.y }
    end
    ForgeMap.markers=result.blips
    return result
end
