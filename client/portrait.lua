ForgePortrait = {}
local camera, trackedPed, activeConfig
local revision, fraction = 0, 1.0

function ForgePortrait.isActive() return camera~=nil end

function ForgePortrait.stop(instant)
    revision=revision+1
    if not camera then return end
    local owned=camera
    camera,trackedPed,activeConfig=nil,nil,nil
    local rendering=GetRenderingCam()
    if rendering==owned or not DoesCamExist(rendering) then
        RenderScriptCams(false, not instant, instant and 0 or Config.Portrait.transition, true, true)
    end
    DestroyCam(owned, false)
end

local function coordinates(ped,cfg)
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local origin = GetEntityCoords(ped)
    -- NUI JSON can decode whole values as Lua integers. Native float slots must
    -- receive actual floats, even when the administrator enters 4, 10 or 150.
    local offset = GetOffsetFromEntityInWorldCoords(ped, cfg.side+0.0, cfg.distance+0.0, 0.0)
    return {x=head.x,y=head.y,z=head.z-0.12},
        {x=head.x+offset.x-origin.x,y=head.y+offset.y-origin.y,z=head.z+cfg.height}
end

local function clearance(ped,cfg)
    local target,destination=coordinates(ped,cfg)
    local dx,dy,dz=destination.x-target.x,destination.y-target.y,destination.z-target.z
    local length=math.sqrt(dx*dx+dy*dy+dz*dz)
    if length<0.65 then return nil,'A câmera está próxima demais da cabeça. Aumente a distância ou os deslocamentos.' end
    local raycast=pr_lib.fivem and pr_lib.fivem.raycast
    if not raycast or not raycast.fromCoords then return 1.0 end
    -- World, vehicles and props; ignore the portrait's ped, not nearby walls.
    local hit,_,point=raycast.fromCoords(target,destination,19,4,ped)
    if not hit or not point then return 1.0 end
    local hx,hy,hz=point.x-target.x,point.y-target.y,point.z-target.z
    local available=math.max(0,math.sqrt(hx*hx+hy*hy+hz*hz)-0.18)
    if available<0.65 then return nil,'Sem espaço para enquadrar o personagem. Afaste-se da parede ou do objeto e tente novamente.' end
    return math.min(1.0,available/length)
end

local function position(owned,ped,cfg,scale)
    local target,destination=coordinates(ped,cfg)
    SetCamCoord(owned,(target.x+(destination.x-target.x)*scale)+0.0,(target.y+(destination.y-target.y)*scale)+0.0,(target.z+(destination.z-target.z)*scale)+0.0)
    PointCamAtCoord(owned,target.x+0.0,target.y+0.0,target.z+0.0)
end

function ForgePortrait.start(instant)
    revision=revision+1
    local current=revision
    if not Config.Portrait.enabled then ForgePortrait.stop(true);return false,'A câmera do personagem está desativada.' end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return false,'A prévia da câmera está indisponível neste estado do personagem.' end
    local rendering=GetRenderingCam()
    if not IsGameplayCamRendering() and rendering~=camera and DoesCamExist(rendering) then
        return false,'Outra câmera está ativa. Encerre-a antes de abrir esta prévia.'
    end
    local cfg=PauseSettings.copy(Config.Portrait)
    local scale,message=clearance(ped,cfg)
    -- PR Bridge raycasts may yield. A closed/replaced preview must not resume here.
    if current~=revision then return false,'Esta solicitação de prévia foi substituída.' end
    if not scale then ForgePortrait.stop(true);return false,message end
    if camera and trackedPed~=ped then ForgePortrait.stop(true) end
    local fresh=not camera
    if fresh then camera=CreateCam('DEFAULT_SCRIPTED_CAMERA',true);SetCamNearClip(camera,0.05) end
    local owned=camera
    trackedPed = ped
    activeConfig,fraction=cfg,scale
    SetCamFov(owned,cfg.fov+0.0)
    position(owned,ped,cfg,scale)
    if fresh then
        RenderScriptCams(true,not instant,instant and 0 or math.floor(cfg.transition),true,true)
        CreateThread(function()
            local nextProbe=GetGameTimer()+250
            while camera==owned do
                if PlayerPedId()~=ped or not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedInAnyVehicle(ped,false) then ForgePortrait.stop(true);return end
                if GetGameTimer()>=nextProbe then
                    local expected=revision
                    local safe,reason=clearance(ped,activeConfig)
                    if camera~=owned then return end
                    if expected==revision then
                        if not safe then
                            ForgePortrait.stop(true)
                            SendNUIMessage({action='portraitPreview',active=false,message=reason})
                            return
                        end
                        fraction=safe
                    end
                    nextProbe=GetGameTimer()+250
                end
                position(owned,ped,activeConfig,fraction)
                Wait(0)
            end
        end)
    end
    if scale<.99 then return true,('Prévia ajustada por obstáculo: distância de %.2f m (solicitada: %.2f m).'):format(cfg.distance*scale,cfg.distance) end
    return true
end
