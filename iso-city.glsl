// This Ghostty shader is a port of https://www.shadertoy.com/view/MljXzz

#define RGB( r, g, b ) vec3( float( r ) / 255.0, float( g ) / 255.0, float( b ) / 255.0 )
const vec3 RGB_WATER = RGB(52, 166, 202);
const vec3 RGB_BUILDING = RGB(219, 180, 144);
const vec3 RGB_RIGHT_WALL = RGB_BUILDING * 1.1;
const vec3 RGB_LEFT_WALL = RGB_BUILDING * 0.7;
const vec3 RGB_WINDOWS = RGB(90, 100, 180);
const vec3 RGB_ROAD = RGB(110, 125, 120) * 0.7;
const vec3 RGB_LANE = RGB(255, 255, 255) * 0.8;
const vec3 RGB_GRASS = RGB(129, 164, 66);
const vec3 RGB_TREE_LEAVES = RGB(129, 164, 66) * 0.6;
const vec3 RGB_TREE_TRUNK = RGB(80, 42, 42);
const float TILE_WATER = 0.0;
const float TILE_GRASS = 1.0;
const float TILE_ISLAND = 2.0;
const float TILE_ROAD_X = 3.0;
const float TILE_ROAD_Y = 4.0;
const float TILE_ROAD_XY = 5.0;
const float ISO_TILE = 13.0 * 8.0;
const float LARGE_FLOAT = 1e8;

void DrawBuilding(inout vec3 color, inout float zbuffer, vec2 tile, vec2 pixel, vec2 buildingTile, float h)
{
    float depth = buildingTile.x + buildingTile.y;
    if (depth > zbuffer)
    {
        return;
    }

    buildingTile.x += h;
    buildingTile.y += h;

    pixel.y -= ISO_TILE * 0.25;
    vec2 iso = vec2((pixel.x + 2.0 * pixel.y) / ISO_TILE, (pixel.x - 2.0 * pixel.y) / -ISO_TILE);
    tile = floor(iso);
    vec2 off = iso - tile;

    // roof
    if (tile.x == buildingTile.x && tile.y == buildingTile.y && off.x > 0.2 && off.y > 0.2 && off.x < 0.98 && off.y < 0.98)
    {
        zbuffer = depth;
        color = RGB_BUILDING;

        if (off.x < 0.28 || off.y < 0.28 || off.x > 1.0 - 0.08 || off.y > 1.0 - 0.08)
        {
            color *= 1.2;
        }
    }

    float px = (buildingTile.x - buildingTile.y) * ISO_TILE * 0.5;

    // right wall
    if (pixel.x >= px && pixel.x < px + 0.39 * ISO_TILE && iso.y < buildingTile.y + 0.20 && iso.y > buildingTile.y - h - 0.4)
    {
        zbuffer = depth;
        color = RGB_RIGHT_WALL;

        if (mod(iso.y + 0.2, 0.5) < 0.25)
        {
            color *= RGB_WINDOWS;
            color *= mod(pixel.x, 16.0) < 8.0 ? 1.0 : 0.8;
        }
    }

    // left wall
    if (pixel.x >= px - 0.39 * ISO_TILE && pixel.x < px && iso.x < buildingTile.x + 0.20 && iso.x > buildingTile.x - h - 0.4)
    {
        zbuffer = depth;
        color = RGB_LEFT_WALL;

        if (mod(iso.x + 0.2, 0.5) < 0.25)
        {
            color *= RGB_WINDOWS;
            color *= mod(pixel.x, 16.0) < 8.0 ? 1.0 : 0.8;
        }
    }
}

void DrawTree(inout vec3 color, inout float zbuffer, vec2 tile, vec2 pixel, vec2 treeTile)
{
    float depth = treeTile.x + treeTile.y;
    if (depth > zbuffer)
    {
        return;
    }

    pixel.y -= ISO_TILE * 0.25;
    vec2 iso = vec2((pixel.x + 2.0 * pixel.y) / ISO_TILE, (pixel.x - 2.0 * pixel.y) / -ISO_TILE);
    tile = floor(iso);
    vec2 off = iso - tile;

    float px = (treeTile.x - treeTile.y) * ISO_TILE * 0.5;

    // top leaves
    if (iso.x > treeTile.x + 0.2 && iso.y > treeTile.y + 0.2 && iso.x < treeTile.x + 0.45 && iso.y < treeTile.y + 0.45)
    {
        zbuffer = depth;
        color = RGB_TREE_LEAVES * 1.0;
    }

    // left leaves
    if (pixel.x >= px - 0.125 * ISO_TILE && pixel.x < px && iso.x > treeTile.x - 0.1 && iso.x < treeTile.x + 0.2 && iso.x > treeTile.x - 0.1)
    {
        zbuffer = depth;
        color = RGB_TREE_LEAVES * 0.8;
    }

    // right leaves
    if (pixel.x >= px && pixel.x < px + 0.125 * ISO_TILE && iso.y < treeTile.y + 0.2 && iso.y > treeTile.y - 0.1)
    {
        zbuffer = depth;
        color = RGB_TREE_LEAVES * 1.2;
    }

    // left trunk
    if (pixel.x >= px - 0.039 * ISO_TILE && pixel.x < px && iso.x <= treeTile.x - 0.1 && iso.x > treeTile.x - 0.4)
    {
        zbuffer = depth;
        color = RGB_TREE_TRUNK * 0.8;
    }

    // right trunk
    if (pixel.x >= px && pixel.x < px + 0.039 * ISO_TILE && iso.y <= treeTile.y - 0.1 && iso.y > treeTile.y - 0.4)
    {
        zbuffer = depth;
        color = RGB_TREE_TRUNK * 1.1;
    }
}

float TileID(vec2 tile)
{
    float id = TILE_WATER;
    vec4 tex = texture(iChannel0, tile / (iChannelResolution[0].xy * 4.0));
    id = tex.y > 0.5 ? TILE_WATER : TILE_GRASS;
    id = tex.y > 0.9 ? TILE_ISLAND : id;

    if (id == TILE_GRASS && mod(tile.x + 1.0, 4.0) == 0.0)
    {
        id = TILE_ROAD_X;
    }

    if (mod(tile.y + 1.0, 4.0) == 0.0)
    {
        if (id == TILE_GRASS)
        {
            id = TILE_ROAD_Y;
        }

        if (id == TILE_ROAD_X)
        {
            id = TILE_ROAD_XY;
        }
    }

    return id;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float resMult = floor(max(iResolution.x, iResolution.y) / 800.0);
    float resRcp = 1.0 / max(resMult, 1.0);
    float cameraOffset = iTime * 10.0 + 0.5;
    // float cameraOffset = float(iFrame);
    vec2 pixel = fragCoord * resRcp + cameraOffset - iMouse.xy + vec2(-2000, -2000.0);
    pixel.y = -pixel.y;

    vec2 iso = vec2((pixel.x + 2.0 * pixel.y) / ISO_TILE, (pixel.x - 2.0 * pixel.y) / -ISO_TILE);
    vec2 waterIso = vec2((pixel.x + 2.0 * pixel.y + 0.15625 * ISO_TILE) / ISO_TILE, (pixel.x - 2.0 * pixel.y - 0.15625 * ISO_TILE) / -ISO_TILE);
    vec2 isoR = vec2((pixel.x + 2.0 * pixel.y - ISO_TILE * 0.5) / ISO_TILE, (pixel.x - 2.0 * pixel.y + ISO_TILE * 0.5) / -ISO_TILE);
    vec2 tile = floor(iso);
    vec2 tileR = floor(isoR);
    vec2 waterTile = floor(waterIso);
    vec2 off = iso - tile;
    vec2 offR = isoR - tileR;
    vec2 waterOff = waterIso - waterTile;

    vec2 buildingTile0 = 2.0 * floor(tile / 2.0);
    vec2 buildingTile1 = 3.0 * floor(tile / 3.0);
    vec2 buildingTile2 = 4.0 * floor(tile / 4.0);
    vec2 buildingTile3 = 5.0 * floor(tile / 5.0);

    float tileId = TileID(tile);
    float tileLId = TileID(vec2(tile.x - 1.0, tile.y));
    float tileRId = TileID(vec2(tile.x + 1.0, tile.y));
    float tileTId = TileID(vec2(tile.x, tile.y - 1.0));
    float tileBId = TileID(vec2(tile.x, tile.y + 1.0));
    float tileB0Id = TileID(buildingTile0);
    float tileB1Id = TileID(buildingTile1);
    float tileB2Id = TileID(buildingTile2);
    float tileB3Id = TileID(buildingTile3);

    // water
    vec3 waterTexNoise = texture(iChannel0, waterTile / iChannelResolution[0].xy + fract(iTime * 0.005)).xyz;
    vec3 color = RGB_WATER * mix(0.8, 1.1, waterTexNoise.z);

    float waterTileId = TileID(waterTile);
    float waterTileLId = TileID(vec2(waterTile.x - 1.0, waterTile.y));
    float waterTileRId = TileID(vec2(waterTile.x + 1.0, waterTile.y));
    float waterTileTId = TileID(vec2(waterTile.x, waterTile.y - 1.0));
    float waterTileBId = TileID(vec2(waterTile.x, waterTile.y + 1.0));
    float waterTileLTId = TileID(vec2(waterTile.x - 1.0, waterTile.y - 1.0));
    float waterTileLBId = TileID(vec2(waterTile.x - 1.0, waterTile.y + 1.0));
    float waterTileRTId = TileID(vec2(waterTile.x + 1.0, waterTile.y - 1.0));
    float waterTileRBId = TileID(vec2(waterTile.x + 1.0, waterTile.y + 1.0));

    // water shore shadow
    if (waterTileId == TILE_WATER)
    {
        if ((waterTileLId != TILE_WATER && waterOff.x < 8.0 / 32.0)
                || (waterTileRId != TILE_WATER && waterOff.x > 24.0 / 32.0)
                || (waterTileTId != TILE_WATER && waterOff.y < 8.0 / 32.0)
                || (waterTileBId != TILE_WATER && waterOff.y > 24.0 / 32.0)
                || (waterTileLTId != TILE_WATER && waterOff.x < 8.0 / 32.0 && waterOff.y < 8.0 / 32.0)
                || (waterTileLBId != TILE_WATER && waterOff.x < 8.0 / 32.0 && waterOff.y > 24.0 / 32.0)
                || (waterTileRTId != TILE_WATER && waterOff.x > 24.0 / 32.0 && waterOff.y < 8.0 / 32.0)
                || (waterTileRBId != TILE_WATER && waterOff.x > 24.0 / 32.0 && waterOff.y > 24.0 / 32.0)
        )
        {
            color *= vec3(0.8);
        }
    }

    // shores
    float waterPX = (waterTile.x - waterTile.y) * ISO_TILE * 0.5;
    if ((waterTileId != TILE_WATER && pixel.x <= waterPX && waterTileLId == TILE_WATER)
            || (waterTileTId != TILE_WATER && pixel.x > waterPX && waterOff.x < 5.0 / 32.0))
    {
        color = RGB_GRASS * 0.7;
    }
    if ((waterTileId != TILE_WATER && pixel.x > waterPX && waterTileTId == TILE_WATER)
            || (waterTileLId != TILE_WATER && pixel.x <= waterPX && waterOff.x < 5.0 / 32.0))
    {
        color = RGB_GRASS * 0.9;
    }

    // grass and road
    if (tileId != TILE_WATER)
    {
        color = RGB_GRASS;
    }

    float roadWidth = 0.3;
    float laneWidth = 0.03;
    if (((tileId == TILE_ROAD_X || tileId == TILE_ROAD_XY) && abs(0.5 - off.x) < roadWidth)
            && (tileTId != TILE_WATER || tileBId != TILE_WATER)
            && (tileTId != TILE_WATER || off.y >= 0.20)
            && (tileBId != TILE_WATER || off.y <= 0.80)
    )
    {
        color = RGB_ROAD;
        if (abs(0.5 - off.x) < laneWidth && mod(off.y, 0.5) < 0.2 && tileId != TILE_ROAD_XY)
        {
            color = RGB_LANE;
        }
    }
    if ((tileId == TILE_ROAD_Y || tileId == TILE_ROAD_XY) && abs(0.5 - off.y) < roadWidth
            && (tileLId != TILE_WATER || tileRId != TILE_WATER)
            && (tileLId != TILE_WATER || off.x >= 0.20)
            && (tileRId != TILE_WATER || off.x <= 0.80))
    {
        color = RGB_ROAD;
        if (abs(0.5 - off.y) < laneWidth && mod(off.x, 0.5) < 0.2 && tileId != TILE_ROAD_XY)
        {
            color = RGB_LANE;
        }
    }

    if (tileId == TILE_GRASS && (
            (buildingTile0.x == tile.x && buildingTile0.y == tile.y)
                || (buildingTile1.x == tile.x && buildingTile1.y == tile.y)
                || (buildingTile2.x == tile.x && buildingTile2.y == tile.y)
                || (buildingTile3.x == tile.x && buildingTile3.y == tile.y)))
    {
        // building AO
        vec2 offAO = 7.0 * clamp((abs(0.5 - off) - 0.35), 0.0, 1.0);
        color *= clamp(max(offAO.x, offAO.y), 0.0, 1.0);
    }
    else if (tileId == TILE_GRASS || tileId == TILE_ISLAND)
    {
        // tree AO
        color *= clamp(max(8.0 * abs(0.15 - off.x), 8.0 * abs(0.15 - off.y)), 0.0, 1.0);
    }

    float zbuffer = LARGE_FLOAT;
    if (tileB0Id == TILE_GRASS)
    {
        DrawBuilding(color, zbuffer, tile, pixel, buildingTile0, 0.0);
    }

    if (tileB1Id == TILE_GRASS)
    {
        DrawBuilding(color, zbuffer, tile, pixel, buildingTile1, 1.0);
    }

    if (tileB2Id == TILE_GRASS)
    {
        DrawBuilding(color, zbuffer, tile, pixel, buildingTile2, 2.0);
    }

    if (tileB3Id == TILE_GRASS)
    {
        DrawBuilding(color, zbuffer, tile, pixel, buildingTile3, 3.0);
    }

    if ((tileId == TILE_GRASS || tileId == TILE_ISLAND) && zbuffer >= LARGE_FLOAT)
    {
        DrawTree(color, zbuffer, tile, pixel, tile);
    }

    fragColor = vec4(sqrt(color), 1.0);

    vec2 termUV = fragCoord.xy / iResolution.xy;
    vec4 terminalColor = texture(iChannel0, termUV);

    float alpha = step(length(terminalColor.rgb), 0.4);
    vec3 blendedColor = mix(terminalColor.rgb * 1.0, fragColor.rgb * 0.3, alpha);

    fragColor = vec4(blendedColor, terminalColor.a);
}
