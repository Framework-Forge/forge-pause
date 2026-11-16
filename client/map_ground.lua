-- Terrain lookup never moves the player or steals the map's streaming focus.
PauseMapGround={}
local cache,queue,cursor,replaceAt={},{},1,1
local limit,budget=8192,16
local function finite(z) return type(z)=='number' and z==z and z>=-2000 and z<=2500 end
function PauseMapGround.reset() cache,queue,cursor,replaceAt={},{},1,1 end
function PauseMapGround.tick()
    local now=GetGameTimer()
    local checked,probes=0,0
    while checked<math.min(#queue,128) and probes<budget do
        if cursor>#queue then cursor=1 end
        local entry=queue[cursor];cursor=cursor+1;checked=checked+1
        if now>=entry.nextProbe then
            probes=probes+1
            RequestCollisionAtCoord(entry.x,entry.y,entry.z or 0.0)
            local found,z=GetGroundZFor_3dCoord(entry.x,entry.y,2500.0,false)
            if found and finite(z) then entry.z=z+0.0;entry.nextProbe=now+5000
            else entry.nextProbe=now+1000 end
        end
    end
end
function PauseMapGround.height(point,x,y)
    local offset=point.mapOffset==nil and 0.15 or point.mapOffset
    if point.mapGround==false then return (point.z or 0.0)+offset end
    x,y=(x or point.x)+0.0,(y or point.y)+0.0
    local key=('%.3f:%.3f'):format(x,y)
    local entry=cache[key]
    if not entry then
        entry={key=key,x=x,y=y,nextProbe=0}
        -- The GTA heightmap is available without loading remote collisions.
        -- Refine it with the precise surface as the viewed region streams in.
        if GetHeightmapBottomZForPosition then
            local ok,z=pcall(GetHeightmapBottomZForPosition,x,y)
            if ok and finite(z) then entry.z=z+0.0 end
        end
        cache[key]=entry
        if #queue<limit then queue[#queue+1]=entry
        else cache[queue[replaceAt].key]=nil;queue[replaceAt]=entry;replaceAt=replaceAt%limit+1 end
    end
    -- Do not draw an unknown terrain elevation using a stale rooftop Z.
    return entry.z and entry.z+offset or nil
end
