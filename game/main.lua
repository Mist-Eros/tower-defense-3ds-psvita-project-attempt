-- ============================================
-- ELEMENTAL DEFENSE (PS Vita / LÖVE2D)
-- Clean Pixel Art Design - No Special Characters
-- Application Window: 1280x720 (Large!)
-- Grid: 26x13 (30% wider)
-- ============================================

-- ============================================
-- LOVE CONFIGURATION
-- ============================================
function love.conf(t)
    t.window.title = "Elemental Defense"
    t.window.resizable = false
    t.window.fullscreen = false
    t.window.minwidth = 1280
    t.window.minheight = 720
    -- DON'T set width/height here - we'll do it in love.load
end

-- ============================================
-- SCREEN CONSTANTS
-- ============================================
SCREEN_W = 1280
SCREEN_H = 720

-- ============================================
-- GRID SYSTEM (26x13) - 30% WIDER
-- ============================================
grid = {
    cols = 26,
    rows = 13,
    cellSize = 28,
    offsetX = 0,
    offsetY = 0,
    topScreenHeight = 500,
}

function calculateGridOffset()
    local totalWidth = grid.cols * grid.cellSize
    local totalHeight = grid.rows * grid.cellSize
    grid.offsetX = (SCREEN_W - totalWidth) / 2
    grid.offsetY = ((grid.topScreenHeight - totalHeight) / 2) + 10
end
calculateGridOffset()

gridData = {}
for col = 1, grid.cols do
    gridData[col] = {}
    for row = 1, grid.rows do
        gridData[col][row] = nil
    end
end

-- ============================================
-- PATHFINDING
-- ============================================
startCol, startRow = 1, 13
endCol, endRow = 26, 13

currentPath = {}
pathPositions = {}

function findPath()
    local queue = {{col = startCol, row = startRow}}
    local visited = {}
    local parent = {}
    visited[startCol] = visited[startCol] or {}
    visited[startCol][startRow] = true
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        
        if current.col == endCol and current.row == endRow then
            local path = {}
            local node = current
            while node do
                table.insert(path, 1, {col = node.col, row = node.row})
                local p = parent[node.col] and parent[node.col][node.row]
                node = p
            end
            return path
        end
        
        local neighbors = {
            {col = current.col, row = current.row - 1},
            {col = current.col, row = current.row + 1},
            {col = current.col - 1, row = current.row},
            {col = current.col + 1, row = current.row},
        }
        
        for _, neighbor in ipairs(neighbors) do
            local c, r = neighbor.col, neighbor.row
            if c >= 1 and c <= grid.cols and r >= 1 and r <= grid.rows then
                if not visited[c] or not visited[c][r] then
                    local hasTower = gridData[c] and gridData[c][r] ~= nil
                    if not hasTower then
                        visited[c] = visited[c] or {}
                        visited[c][r] = true
                        parent[c] = parent[c] or {}
                        parent[c][r] = current
                        table.insert(queue, neighbor)
                    end
                end
            end
        end
    end
    
    return nil
end

function updatePath()
    currentPath = findPath()
    pathPositions = {}
    if currentPath then
        for i, cell in ipairs(currentPath) do
            local x = grid.offsetX + (cell.col - 1) * grid.cellSize + grid.cellSize / 2
            local y = grid.offsetY + (cell.row - 1) * grid.cellSize + grid.cellSize / 2
            table.insert(pathPositions, {x = x, y = y})
        end
    end
end

updatePath()

-- ============================================
-- TOWER TYPES
-- ============================================
towerTypes = {
    {
        name = "Fire", 
        cost = 20, 
        damage = 3, 
        fireRate = 0.8, 
        range = 60, 
        color = {0.95, 0.15, 0.15},
        glowColor = {0.95, 0.3, 0.1},
    },
    {
        name = "Water", 
        cost = 20, 
        damage = 3, 
        fireRate = 0.8, 
        range = 60, 
        color = {0.15, 0.4, 0.95},
        glowColor = {0.1, 0.5, 0.95},
    },
    {
        name = "Forest", 
        cost = 20, 
        damage = 3, 
        fireRate = 0.8, 
        range = 60, 
        color = {0.15, 0.9, 0.15},
        glowColor = {0.1, 0.9, 0.3},
    },
}

enemyTypes = {
    FIRE = {color = {0.95, 0.15, 0.15}, glowColor = {0.95, 0.3, 0.1}, name = "Fire"},
    WATER = {color = {0.15, 0.4, 0.95}, glowColor = {0.1, 0.5, 0.95}, name = "Water"},
    FOREST = {color = {0.15, 0.9, 0.15}, glowColor = {0.1, 0.9, 0.3}, name = "Forest"},
}

function getDamageMultiplier(towerType, enemyType)
    if towerType == 1 then
        if enemyType == "FOREST" then return 2.0 end
        if enemyType == "WATER" then return 0.5 end
        return 1.0
    elseif towerType == 2 then
        if enemyType == "FIRE" then return 2.0 end
        if enemyType == "FOREST" then return 0.5 end
        return 1.0
    elseif towerType == 3 then
        if enemyType == "WATER" then return 2.0 end
        if enemyType == "FIRE" then return 0.5 end
        return 1.0
    end
    return 1.0
end

-- ============================================
-- GAME STATE
-- ============================================
gameState = "MENU"
cursor = {col = 1, row = 1}
gold = 150
selectedTowerType = 1
state = "MOVING"
enemies = {}
wave = 1
enemiesSpawned = 0
enemiesPerWave = 3
enemiesRemaining = 3
enemySpawnTimer = 0
enemySpawnInterval = 3.0
waveActive = false
waveComplete = false
gameStarted = false
gameTime = 0
lasers = {}
totalKills = 0
errorMessage = ""
errorTimer = 0
showControls = false
waveEvents = {}
waveRetry = false
enemiesThatPassed = 0
menuParticles = {}

waveEnemyCounts = {
    FIRE = 0,
    WATER = 0,
    FOREST = 0,
    ELITE = 0
}

speedLevels = {0, 0.5, 1, 2, 4}
speedIndex = 3
gameSpeed = 1

-- Fonts
fontTitle = nil
fontLarge = nil
fontMedium = nil
fontSmall = nil
fontTiny = nil

-- ============================================
-- SOUND SYSTEM
-- ============================================
soundEnabled = true
menuMusic = nil
gameMusic = nil
sfx_build = nil
sfx_sell = nil
sfx_laser = nil
sfx_wave_start = nil
sfx_enemy_die = nil
sfx_gameover = nil
sfx_upgrade = {}
laserSoundCooldown = 0

function loadSounds()
    local function safeLoad(path, stream)
        local ok, sound = pcall(love.audio.newSource, path, stream and "stream" or "static")
        if ok and sound then
            return sound
        end
        return nil
    end
    
    menuMusic = safeLoad("sounds/menu_music.ogg", true)
    if menuMusic then menuMusic:setLooping(true); menuMusic:setVolume(0.5) end
    
    gameMusic = safeLoad("sounds/game_music.ogg", true)
    if gameMusic then gameMusic:setLooping(true); gameMusic:setVolume(0.5) end
    
    sfx_build = safeLoad("sounds/build.wav", false)
    sfx_sell = safeLoad("sounds/sell.wav", false)
    sfx_laser = safeLoad("sounds/laser.wav", false)
    sfx_wave_start = safeLoad("sounds/wave_start.wav", false)
    sfx_enemy_die = safeLoad("sounds/enemy_die.wav", false)
    sfx_gameover = safeLoad("sounds/gameover.wav", false)
    
    for i = 1, 6 do
        local sound = safeLoad("sounds/upgrade_" .. i .. ".wav", false)
        if sound then table.insert(sfx_upgrade, sound) end
    end
end

function playSound(sound)
    if sound and soundEnabled then
        sound:stop()
        sound:play()
    end
end

function playRandomUpgradeSound()
    if not soundEnabled or #sfx_upgrade == 0 then return end
    local sound = sfx_upgrade[math.random(1, #sfx_upgrade)]
    if sound then sound:stop(); sound:play() end
end

function playMenuMusic() if menuMusic and soundEnabled then menuMusic:play() end end
function playGameMusic() if gameMusic and soundEnabled then gameMusic:play() end end
function stopMenuMusic() if menuMusic then menuMusic:stop() end end
function stopGameMusic() if gameMusic then gameMusic:stop() end end

-- ============================================
-- PIXEL ART DRAWING HELPERS
-- ============================================

function drawPixelFire(x, y, size, color)
    local h = size
    local w = size * 0.8
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.polygon("fill",
        x, y - h,
        x - w, y + h * 0.6,
        x - w * 0.3, y + h * 0.2,
        x, y + h * 0.8,
        x + w * 0.3, y + h * 0.2,
        x + w, y + h * 0.6
    )
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.polygon("fill",
        x, y - h * 0.6,
        x - w * 0.4, y + h * 0.3,
        x - w * 0.1, y + h * 0.1,
        x, y + h * 0.4,
        x + w * 0.1, y + h * 0.1,
        x + w * 0.4, y + h * 0.3
    )
end

function drawPixelWater(x, y, size, color)
    local s = size
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.polygon("fill",
        x, y - s,
        x - s * 0.8, y + s * 0.2,
        x - s * 0.5, y + s * 0.6,
        x, y + s,
        x + s * 0.5, y + s * 0.6,
        x + s * 0.8, y + s * 0.2
    )
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.polygon("fill",
        x - s * 0.2, y - s * 0.4,
        x - s * 0.4, y - s * 0.1,
        x - s * 0.2, y - s * 0.1,
        x - s * 0.1, y - s * 0.3
    )
end

function drawPixelLeaf(x, y, size, color)
    local s = size
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.polygon("fill",
        x, y - s,
        x - s * 0.7, y - s * 0.3,
        x - s * 0.8, y + s * 0.2,
        x - s * 0.3, y + s * 0.6,
        x, y + s * 0.4,
        x + s * 0.3, y + s * 0.6,
        x + s * 0.8, y + s * 0.2,
        x + s * 0.7, y - s * 0.3
    )
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.line(x, y - s * 0.5, x, y + s * 0.3)
end

function drawPixelStar(x, y, size, color)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.polygon("fill",
        x, y - size,
        x + size * 0.3, y - size * 0.3,
        x + size, y - size * 0.3,
        x + size * 0.4, y + size * 0.1,
        x + size * 0.6, y + size * 0.8,
        x, y + size * 0.4,
        x - size * 0.6, y + size * 0.8,
        x - size * 0.4, y + size * 0.1,
        x - size, y - size * 0.3,
        x - size * 0.3, y - size * 0.3
    )
end

function drawTower(x, y, type, level, color)
    local size = 12 + math.min(level, 10) * 0.4
    
    if type == 1 then
        drawPixelFire(x, y, size, color)
    elseif type == 2 then
        drawPixelWater(x, y, size, color)
    elseif type == 3 then
        drawPixelLeaf(x, y, size, color)
    end
    
    if level >= 10 then
        love.graphics.setColor(1, 1, 0.3, 1)
        love.graphics.rectangle("fill", x - 5, y - size - 5, 10, 5)
        love.graphics.setColor(1, 1, 0.5, 0.6)
        love.graphics.rectangle("fill", x - 4, y - size - 4, 8, 3)
    else
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(fontTiny)
        love.graphics.printf(level, x - 5, y - size - 6, 10, "center")
    end
end

function drawEnemy(x, y, enemyType, isElite, color)
    local size = isElite and 16 or 10
    
    if enemyType == "FIRE" then
        drawPixelFire(x, y, size, color)
    elseif enemyType == "WATER" then
        drawPixelWater(x, y, size, color)
    elseif enemyType == "FOREST" then
        drawPixelLeaf(x, y, size, color)
    end
    
    if isElite then
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.rectangle("line", x - size - 3, y - size - 3, size * 2 + 6, size * 2 + 6)
        love.graphics.setColor(1, 0.8, 0.2, 0.15)
        love.graphics.rectangle("line", x - size - 4, y - size - 4, size * 2 + 8, size * 2 + 8)
    end
end

function drawHealthBar(x, y, width, health, maxHealth)
    local percent = health / maxHealth
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - width/2, y - 6, width, 5)
    love.graphics.setColor(1 - percent, percent, 0, 1)
    love.graphics.rectangle("fill", x - width/2 + 1, y - 5, (width - 2) * percent, 3)
end

function drawGlow(x, y, color, radius, alpha)
    for i = 4, 1, -1 do
        local a = (i / 4) * (alpha or 0.08)
        local r = radius * (i / 4)
        love.graphics.setColor(color[1], color[2], color[3], a)
        love.graphics.circle("fill", x, y, r)
    end
end

function drawCoin(x, y, radius)
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.circle("fill", x, y, radius)
    love.graphics.setColor(1, 1, 0.5, 0.6)
    love.graphics.circle("fill", x - 1, y - 1, radius * 0.4)
    love.graphics.setColor(0.8, 0.6, 0.1, 1)
    love.graphics.circle("line", x, y, radius)
end

function drawGradientBackground()
    for i = 0, SCREEN_H do
        local t = i / SCREEN_H
        love.graphics.setColor(0.02 + t * 0.03, 0.02 + t * 0.03, 0.05 + t * 0.07, 1)
        love.graphics.rectangle("fill", 0, i, SCREEN_W, 1)
    end
end

-- ============================================
-- HELPERS
-- ============================================
function getGridPosition(col, row)
    local x = grid.offsetX + (col - 1) * grid.cellSize + grid.cellSize / 2
    local y = grid.offsetY + (row - 1) * grid.cellSize + grid.cellSize / 2
    return x, y
end

function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function getPathPosition(t)
    if not pathPositions or #pathPositions < 2 then
        return {x = 0, y = 0}
    end
    
    local totalSegments = #pathPositions - 1
    local segmentLength = 1 / totalSegments
    local segmentIndex = math.floor(t / segmentLength) + 1
    local localT = (t % segmentLength) / segmentLength
    
    if segmentIndex >= #pathPositions then
        local last = pathPositions[#pathPositions]
        return {x = last.x, y = last.y}
    end
    
    local p1 = pathPositions[segmentIndex]
    local p2 = pathPositions[segmentIndex + 1]
    
    return {
        x = p1.x + (p2.x - p1.x) * localT,
        y = p1.y + (p2.y - p1.y) * localT
    }
end

function isPathCell(col, row)
    if not currentPath then return false end
    for i, cell in ipairs(currentPath) do
        if cell.col == col and cell.row == row then
            return true
        end
    end
    return false
end

function showError(msg)
    errorMessage = msg
    errorTimer = 2.0
end

function getSpeedText()
    if speedLevels[speedIndex] == 0 then return "PAUSED" end
    return speedLevels[speedIndex] .. "x"
end

function getTotalCost(tower)
    local total = 20
    for i = 2, tower.level do
        total = total + (20 * (2 ^ (i - 2)))
    end
    return total
end

-- ============================================
-- WAVE SYSTEM
-- ============================================
function startWave()
    waveActive = true
    waveComplete = false
    enemiesSpawned = 0
    
    waveEnemyCounts = {
        FIRE = 0,
        WATER = 0,
        FOREST = 0,
        ELITE = 0
    }
    
    playSound(sfx_wave_start)
    
    local baseEnemies = 3 + wave * 2
    enemiesPerWave = baseEnemies
    enemiesRemaining = enemiesPerWave
    
    waveEvents = {}
    local eliteCount = 0
    
    if wave % 25 == 0 then
        eliteCount = 10
        for i = 1, 10 do
            table.insert(waveEvents, {type = "ELITE", delay = i * 0.3})
        end
        enemiesPerWave = enemiesPerWave + 10
        enemiesRemaining = enemiesRemaining + 10
        waveEnemyCounts.ELITE = 10
    elseif wave % 10 == 0 then
        eliteCount = 3
        for i = 1, 3 do
            table.insert(waveEvents, {type = "ELITE", delay = i * 0.2})
        end
        enemiesPerWave = enemiesPerWave + 3
        enemiesRemaining = enemiesRemaining + 3
        waveEnemyCounts.ELITE = 3
    elseif wave % 5 == 0 then
        eliteCount = 1
        table.insert(waveEvents, {type = "ELITE", delay = 0.5})
        enemiesPerWave = enemiesPerWave + 1
        enemiesRemaining = enemiesRemaining + 1
        waveEnemyCounts.ELITE = 1
    end
    
    local regularCount = baseEnemies - eliteCount
    local fireCount = math.floor(regularCount / 3)
    local waterCount = math.floor(regularCount / 3)
    local forestCount = regularCount - fireCount - waterCount
    
    waveEnemyCounts.FIRE = fireCount
    waveEnemyCounts.WATER = waterCount
    waveEnemyCounts.FOREST = forestCount
    
    enemySpawnInterval = math.max(0.8, 3.0 - wave * 0.05)
    enemySpawnTimer = 0
    enemiesThatPassed = 0
    waveRetry = false
end

function getRandomEnemyType()
    local types = {"FIRE", "WATER", "FOREST"}
    return types[math.random(1, 3)]
end

-- ============================================
-- MENU PARTICLES
-- ============================================
function spawnMenuParticles()
    for i = 1, 4 do
        table.insert(menuParticles, {
            x = math.random(0, SCREEN_W),
            y = math.random(0, SCREEN_H),
            vx = (math.random() - 0.5) * 60,
            vy = (math.random() - 0.5) * 60,
            life = 1 + math.random() * 3,
            maxLife = 1 + math.random() * 3,
            size = math.random(2, 5),
            color = {
                math.random(0.2, 0.8),
                math.random(0.2, 0.8),
                math.random(0.2, 0.8)
            }
        })
    end
end

function updateMenuParticles(dt)
    for i = #menuParticles, 1, -1 do
        local p = menuParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        
        if p.x < 0 or p.x > SCREEN_W then p.vx = -p.vx end
        if p.y < 0 or p.y > SCREEN_H then p.vy = -p.vy end
        
        if p.life <= 0 then
            table.remove(menuParticles, i)
        end
    end
    spawnMenuParticles()
end

-- ============================================
-- UPDATE
-- ============================================
function love.update(dt)
    if gameState == "MENU" then
        updateMenuParticles(dt)
        return
    end
    
    dt = dt * gameSpeed
    
    laserSoundCooldown = math.max(0, laserSoundCooldown - dt)
    
    if errorTimer > 0 then
        errorTimer = errorTimer - dt
        if errorTimer < 0 then errorTimer = 0 end
    end
    
    gameTime = gameTime + dt
    
    for i = #lasers, 1, -1 do
        lasers[i].life = lasers[i].life - dt
        if lasers[i].life <= 0 then
            table.remove(lasers, i)
        end
    end
    
    if wave == 1 and not gameStarted and not waveActive then
        -- Waiting for player
    elseif not waveActive and not waveComplete and gameStarted then
        startWave()
    end
    
    if waveActive then
        enemySpawnTimer = enemySpawnTimer + dt
        if enemySpawnTimer >= enemySpawnInterval and enemiesSpawned < enemiesPerWave then
            enemySpawnTimer = 0
            enemiesSpawned = enemiesSpawned + 1
            
            local isElite = false
            if waveEvents and #waveEvents > 0 then
                for i = #waveEvents, 1, -1 do
                    local event = waveEvents[i]
                    if event.delay <= 0 then
                        isElite = true
                        table.remove(waveEvents, i)
                        break
                    end
                    event.delay = event.delay - enemySpawnInterval
                end
            end
            
            if pathPositions and #pathPositions > 0 then
                local enemyType = getRandomEnemyType()
                local health = 15 + (wave - 1) * 3
                local speed = 20 + (wave - 1) * 1
                
                if isElite then
                    health = health * 2.5
                    speed = speed * 1.8
                end
                
                table.insert(enemies, {
                    t = 0,
                    health = health,
                    maxHealth = health,
                    speed = speed,
                    x = pathPositions[1].x,
                    y = pathPositions[1].y,
                    type = enemyType,
                    color = enemyTypes[enemyType].color,
                    isElite = isElite,
                })
            end
        end
    end
    
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        enemy.t = enemy.t + dt * (enemy.speed / 100)
        
        if enemy.t >= 1 then
            table.remove(enemies, i)
            enemiesRemaining = enemiesRemaining - 1
            enemiesThatPassed = enemiesThatPassed + 1
            
            if enemy.isElite then
                gold = gold + 10
            else
                gold = gold + 2
            end
        else
            local pos = getPathPosition(enemy.t)
            enemy.x = pos.x
            enemy.y = pos.y
        end
    end
    
    for col = 1, grid.cols do
        for row = 1, grid.rows do
            local tower = gridData[col][row]
            if tower then
                tower.cooldown = math.max(0, tower.cooldown - dt)
                
                local tx, ty = getGridPosition(col, row)
                local range = towerTypes[tower.type].range
                local target = nil
                
                for j, enemy in ipairs(enemies) do
                    local dist = distance(tx, ty, enemy.x, enemy.y)
                    if dist <= range then
                        if not target then
                            target = enemy
                        else
                            local currentDist = distance(tx, ty, target.x, target.y)
                            if dist < currentDist then
                                target = enemy
                            end
                        end
                    end
                end
                
                if target and tower.cooldown <= 0 then
                    tower.cooldown = tower.fireRate
                    
                    local multiplier = getDamageMultiplier(tower.type, target.type)
                    local damage = tower.damage * multiplier
                    
                    target.health = target.health - damage
                    
                    table.insert(lasers, {
                        x1 = tx,
                        y1 = ty,
                        x2 = target.x,
                        y2 = target.y,
                        color = tower.color,
                        life = 0.15,
                        maxLife = 0.15
                    })
                    
                    if laserSoundCooldown <= 0 then
                        playSound(sfx_laser)
                        laserSoundCooldown = 0.08
                    end
                    
                    if target.health <= 0 then
                        gold = gold + 10
                        totalKills = totalKills + 1
                        enemiesRemaining = enemiesRemaining - 1
                        playSound(sfx_enemy_die)
                        for j, enemy in ipairs(enemies) do
                            if enemy == target then
                                table.remove(enemies, j)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    
    if waveActive and enemiesSpawned >= enemiesPerWave and #enemies == 0 and enemiesRemaining <= 0 then
        waveActive = false
        waveComplete = true
        
        if enemiesThatPassed > 0 then
            waveRetry = true
        end
    end
    
    if waveComplete and waveRetry then
        waveRetry = false
        waveComplete = false
        startWave()
    end
    
    if waveComplete and not waveRetry and gameStarted then
        wave = wave + 1
        waveComplete = false
        startWave()
    end
end

-- ============================================
-- DRAW MAIN MENU
-- ============================================
function drawMainMenu()
    drawGradientBackground()
    
    for i, p in ipairs(menuParticles) do
        local alpha = p.life / p.maxLife
        drawGlow(p.x, p.y, p.color, p.size * 2, alpha * 0.3)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end
    
    local panelX, panelY, panelW, panelH = 290, 80, 700, 560
    love.graphics.setColor(0.04, 0.04, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 4, 4)
    love.graphics.setColor(0.15, 0.15, 0.30, 0.4)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 4, 4)
    
    drawGlow(640, 200, {1, 0.7, 0.2}, 100, 0.15)
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 0.9, 0.4, 1)
    love.graphics.printf("ELEMENTAL", 440, 160, 400, "center")
    
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
    love.graphics.printf("DEFENSE", 480, 215, 280, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("DEFENSE", 478, 213, 280, "center")
    
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.5, 0.5, 0.7, 0.6)
    love.graphics.printf("Tower Defense", 500, 265, 280, "center")
    
    love.graphics.setColor(0.3, 0.2, 0.1, 0.2)
    love.graphics.rectangle("fill", 440, 295, 400, 1)
    
    local elements = {{0.95,0.15,0.15}, {0.15,0.4,0.95}, {0.15,0.9,0.15}}
    local names = {"Fire", "Water", "Forest"}
    for i = 1, 3 do
        local x = 420 + (i-1) * 220
        local y = 320
        
        drawGlow(x, y, elements[i], 25, 0.12)
        
        if i == 1 then
            drawPixelFire(x, y, 18, elements[i])
        elseif i == 2 then
            drawPixelWater(x, y, 18, elements[i])
        else
            drawPixelLeaf(x, y, 18, elements[i])
        end
        
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.4, 0.4, 0.6, 0.5)
        love.graphics.printf(names[i], x - 25, y + 28, 50, "center")
    end
    
    local btnX, btnY = 570, 400
    local btnW, btnH = 140, 55
    
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", btnX + 4, btnY + 4, btnW, btnH, 28, 28)
    
    love.graphics.setColor(0.85, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 28, 28)
    love.graphics.setColor(1, 0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", btnX + 3, btnY + 3, btnW - 6, btnH/2, 25, 25)
    
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("START", btnX, btnY + 14, btnW, "center")
    
    love.graphics.setFont(fontTiny)
    love.graphics.setColor(0.3, 0.3, 0.5, 0.4)
    love.graphics.printf("Press SELECT for controls", 520, 590, 240, "center")
end

-- ============================================
-- DRAW CONTROLS OVERLAY
-- ============================================
function drawControlsOverlay()
    love.graphics.setColor(0, 0, 0, 0.90)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
    
    local panelX, panelY, panelW, panelH = 290, 70, 700, 580
    love.graphics.setColor(0.04, 0.04, 0.10, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 4, 4)
    love.graphics.setColor(0.15, 0.15, 0.30, 0.4)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 4, 4)
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("CONTROLS", 540, 100, 200, "center")
    
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(0.8, 0.8, 0.9, 0.9)
    
    local controls = {
        "D-Pad / Touch : Move cursor",
        "A / Tap       : Select / Build",
        "B             : Cancel",
        "L / R         : Speed control",
        "X             : Upgrade tower",
        "Y (twice)     : Sell tower",
        "SELECT        : Toggle menu",
    }
    
    for i, text in ipairs(controls) do
        local y = 180 + (i-1) * 50
        love.graphics.printf(text, 380, y, 500, "left")
    end
    
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.5, 0.5, 0.7, 0.4)
    love.graphics.printf("Press SELECT again to close", 540, 580, 200, "center")
end

-- ============================================
-- DRAW GAME AREA
-- ============================================
function drawGameArea()
    drawGradientBackground()
    
    -- Grid background
    love.graphics.setColor(0.03, 0.03, 0.06, 1)
    love.graphics.rectangle("fill", grid.offsetX - 2, grid.offsetY - 2, 
        grid.cols * grid.cellSize + 4, grid.rows * grid.cellSize + 4)
    
    love.graphics.setColor(0.1, 0.1, 0.2, 0.3)
    love.graphics.rectangle("line", grid.offsetX - 2, grid.offsetY - 2, 
        grid.cols * grid.cellSize + 4, grid.rows * grid.cellSize + 4)
    
    -- Path
    if currentPath then
        for i, cell in ipairs(currentPath) do
            local x = grid.offsetX + (cell.col - 1) * grid.cellSize
            local y = grid.offsetY + (cell.row - 1) * grid.cellSize
            local t = i / #currentPath
            love.graphics.setColor(0.2 + t * 0.08, 0.12 + t * 0.04, 0.04 + t * 0.02, 1)
            love.graphics.rectangle("fill", x, y, grid.cellSize, grid.cellSize)
            love.graphics.setColor(0.25, 0.18, 0.08, 0.15)
            love.graphics.rectangle("line", x, y, grid.cellSize, grid.cellSize)
        end
    end
    
    -- Grid cells
    for col = 1, grid.cols do
        for row = 1, grid.rows do
            local x = grid.offsetX + (col - 1) * grid.cellSize
            local y = grid.offsetY + (row - 1) * grid.cellSize
            
            if not isPathCell(col, row) then
                local tower = gridData[col][row]
                if tower then
                    love.graphics.setColor(tower.color[1], tower.color[2], tower.color[3], 0.06)
                    love.graphics.rectangle("fill", x, y, grid.cellSize, grid.cellSize)
                else
                    love.graphics.setColor(0.05, 0.05, 0.08, 1)
                    love.graphics.rectangle("fill", x, y, grid.cellSize, grid.cellSize)
                end
            end
            
            love.graphics.setColor(0.08, 0.08, 0.12, 0.12)
            love.graphics.rectangle("line", x, y, grid.cellSize, grid.cellSize)
        end
    end
    
    -- Towers
    for col = 1, grid.cols do
        for row = 1, grid.rows do
            local tower = gridData[col][row]
            if tower then
                local cx, cy = getGridPosition(col, row)
                local tType = towerTypes[tower.type]
                
                if state == "TOWER_SELECTED" and cursor.col == col and cursor.row == row then
                    love.graphics.setColor(tower.color[1], tower.color[2], tower.color[3], 0.06)
                    love.graphics.circle("fill", cx, cy, tType.range)
                    love.graphics.setColor(tower.color[1], tower.color[2], tower.color[3], 0.15)
                    love.graphics.circle("line", cx, cy, tType.range)
                end
                
                drawTower(cx, cy, tower.type, tower.level, tower.color)
            end
        end
    end
    
    -- Lasers
    for i, laser in ipairs(lasers) do
        local alpha = laser.life / laser.maxLife
        love.graphics.setColor(laser.color[1], laser.color[2], laser.color[3], alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(laser.x1, laser.y1, laser.x2, laser.y2)
        love.graphics.setColor(laser.color[1], laser.color[2], laser.color[3], alpha * 0.1)
        love.graphics.setLineWidth(5)
        love.graphics.line(laser.x1, laser.y1, laser.x2, laser.y2)
    end
    
    -- Enemies
    for i, enemy in ipairs(enemies) do
        drawEnemy(enemy.x, enemy.y, enemy.type, enemy.isElite, enemy.color)
        drawHealthBar(enemy.x, enemy.y - 18, 24, enemy.health, enemy.maxHealth)
    end
    
    -- Cursor
    local x = grid.offsetX + (cursor.col - 1) * grid.cellSize
    local y = grid.offsetY + (cursor.row - 1) * grid.cellSize
    
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", x, y, grid.cellSize, grid.cellSize)
    
    local s = 4
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.rectangle("fill", x, y, s, s)
    love.graphics.rectangle("fill", x + grid.cellSize - s, y, s, s)
    love.graphics.rectangle("fill", x, y + grid.cellSize - s, s, s)
    love.graphics.rectangle("fill", x + grid.cellSize - s, y + grid.cellSize - s, s, s)
    
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", x, y, grid.cellSize, grid.cellSize)
    
    if state == "BUILDING" then
        love.graphics.setColor(1, 1, 0.3, 0.15)
        love.graphics.rectangle("fill", x, y, grid.cellSize, grid.cellSize)
        love.graphics.setColor(1, 1, 0.3, 0.3)
        love.graphics.rectangle("line", x, y, grid.cellSize, grid.cellSize)
    end
    
    if not gameStarted then
        love.graphics.setFont(fontLarge)
        love.graphics.setColor(1, 1, 0.6, 0.8)
        love.graphics.printf("BUILD YOUR DEFENSE", 490, 100, 300, "center")
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.printf("Press A to start Wave 1", 520, 140, 240, "center")
        love.graphics.printf("Build on path cells to redirect enemies", 480, 170, 320, "center")
    end
end

-- ============================================
-- DRAW UI PANEL (Bottom)
-- ============================================
function drawUIPanel()
    local panelY = grid.topScreenHeight + 5
    local panelH = SCREEN_H - panelY
    
    love.graphics.setColor(0.03, 0.03, 0.07, 0.95)
    love.graphics.rectangle("fill", 0, panelY, SCREEN_W, panelH)
    love.graphics.setColor(0.1, 0.1, 0.2, 0.2)
    love.graphics.rectangle("fill", 0, panelY, SCREEN_W, 1)
    
    -- ========================================
    -- LEFT SECTION: WAVE DISPLAY
    -- ========================================
    local leftX = 30
    local topY = panelY + 8
    
    -- WAVE label
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.5, 0.5, 0.7, 0.6)
    love.graphics.printf("WAVE", leftX, topY, 100, "center")
    
    -- Wave number - LARGE
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(wave, leftX, topY + 25, 100, "center")
    
    -- Status
    local status = "WAITING"
    local statusColor = {0.5, 0.5, 0.5}
    if not gameStarted then
        status = "READY"
        statusColor = {1, 1, 0.4}
    elseif waveActive then
        status = "ACTIVE"
        statusColor = {0.2, 0.9, 0.2}
    elseif waveComplete then
        status = "COMPLETE"
        statusColor = {1, 1, 0.3}
    end
    
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(statusColor[1], statusColor[2], statusColor[3], 0.9)
    love.graphics.printf(status, leftX, topY + 75, 100, "center")
    
    -- Enemies remaining
    love.graphics.setColor(0.5, 0.5, 0.7, 0.5)
    love.graphics.printf("LEFT", leftX, topY + 95, 100, "center")
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(fontLarge)
    love.graphics.printf(enemiesRemaining, leftX, topY + 115, 100, "center")
    
    -- ========================================
    -- RIGHT SECTION: WAVE ENEMY COMPOSITION
    -- ========================================
    local rightX = SCREEN_W - 30
    local rightY = panelY + 8
    
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.5, 0.5, 0.7, 0.6)
    love.graphics.printf("WAVE ENEMIES", rightX, rightY, 200, "right")
    
    local enemyList = {
        {name = "Fire", count = waveEnemyCounts.FIRE, color = {0.95, 0.15, 0.15}},
        {name = "Water", count = waveEnemyCounts.WATER, color = {0.15, 0.4, 0.95}},
        {name = "Forest", count = waveEnemyCounts.FOREST, color = {0.15, 0.9, 0.15}},
        {name = "Elite", count = waveEnemyCounts.ELITE, color = {1, 0.8, 0.2}},
    }
    
    local yOff = rightY + 25
    for i, item in ipairs(enemyList) do
        if item.count > 0 then
            local iconX = rightX - 170
            if item.name == "Fire" then
                drawPixelFire(iconX, yOff + 8, 8, item.color)
            elseif item.name == "Water" then
                drawPixelWater(iconX, yOff + 8, 8, item.color)
            elseif item.name == "Forest" then
                drawPixelLeaf(iconX, yOff + 8, 8, item.color)
            else
                drawPixelStar(iconX, yOff + 8, 8, item.color)
            end
            
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(item.color[1], item.color[2], item.color[3], 0.8)
            love.graphics.printf(item.name, rightX - 145, yOff, 100, "left")
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.printf("x" .. item.count, rightX - 45, yOff, 40, "right")
            
            yOff = yOff + 24
        end
    end
    
    if yOff == rightY + 25 then
        love.graphics.setColor(0.4, 0.4, 0.6, 0.4)
        love.graphics.setFont(fontSmall)
        love.graphics.printf("---", rightX, yOff + 8, 80, "center")
    end
    
    -- ========================================
    -- BOTTOM SECTION: Gold, Speed, Build Buttons
    -- ========================================
    local bottomY = panelY + panelH - 55
    
    -- Gold
    drawCoin(30, bottomY + 12, 14)
    love.graphics.setColor(1, 0.9, 0.3, 1)
    love.graphics.setFont(fontLarge)
    love.graphics.printf(gold, 55, bottomY + 4, 80, "left")
    
    -- Speed
    love.graphics.setColor(0.5, 0.5, 0.7, 0.5)
    love.graphics.setFont(fontSmall)
    love.graphics.printf("SPEED", 150, bottomY + 4, 60, "left")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(fontMedium)
    love.graphics.printf(getSpeedText(), 150, bottomY + 22, 60, "left")
    
    -- Build buttons
    love.graphics.setColor(0.5, 0.5, 0.7, 0.4)
    love.graphics.setFont(fontTiny)
    love.graphics.printf("BUILD:", 250, bottomY + 4, 50, "left")
    
    local btnY = bottomY + 2
    for i = 1, 3 do
        local t = towerTypes[i]
        local x = 310 + (i-1) * 100
        local isSelected = (state == "BUILDING" and selectedTowerType == i)
        
        love.graphics.setColor(0.08, 0.08, 0.14, 0.6)
        love.graphics.rectangle("fill", x, btnY, 88, 38, 4, 4)
        
        if isSelected then
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], 0.2)
            love.graphics.rectangle("fill", x + 2, btnY + 2, 84, 34, 3, 3)
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], 0.4)
            love.graphics.rectangle("line", x, btnY, 88, 38, 4, 4)
        end
        
        if i == 1 then
            drawPixelFire(x + 18, btnY + 18, 12, t.color)
        elseif i == 2 then
            drawPixelWater(x + 18, btnY + 18, 12, t.color)
        else
            drawPixelLeaf(x + 18, btnY + 18, 12, t.color)
        end
        
        love.graphics.setFont(fontTiny)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf(t.cost, x + 38, btnY + 12, 40, "left")
    end
    
    -- ========================================
    -- CENTER SECTION: Cell Info
    -- ========================================
    local infoY = panelY + 8
    local infoX = 490
    local infoW = 560
    
    love.graphics.setColor(0.04, 0.04, 0.08, 0.6)
    love.graphics.rectangle("fill", infoX, infoY - 2, infoW, 60)
    love.graphics.setColor(0.1, 0.1, 0.2, 0.15)
    love.graphics.rectangle("line", infoX, infoY - 2, infoW, 60)
    
    local tower = gridData[cursor.col] and gridData[cursor.col][cursor.row]
    love.graphics.setFont(fontSmall)
    
    if state == "BUILDING" then
        local t = towerTypes[selectedTowerType]
        love.graphics.setColor(t.color[1], t.color[2], t.color[3], 0.9)
        love.graphics.printf(t.name, infoX + 15, infoY + 4, 60, "left")
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("DAMAGE: " .. t.damage, infoX + 80, infoY + 4, 100, "left")
        love.graphics.setColor(1, 0.9, 0.3, 0.6)
        love.graphics.printf("COST: " .. t.cost .. "G", infoX + 190, infoY + 4, 100, "left")
        
        love.graphics.setColor(0.4, 0.4, 0.6, 0.5)
        if isPathCell(cursor.col, cursor.row) then
            love.graphics.printf("PATH CELL - Building redirects enemies", infoX + 15, infoY + 35, 500, "left")
        else
            love.graphics.printf("Press A to build  |  B to cancel", infoX + 15, infoY + 35, 350, "left")
        end
        
    elseif tower then
        local t = towerTypes[tower.type]
        love.graphics.setColor(t.color[1], t.color[2], t.color[3], 0.9)
        love.graphics.printf(t.name, infoX + 15, infoY + 4, 60, "left")
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("LV." .. tower.level, infoX + 80, infoY + 4, 60, "left")
        love.graphics.setColor(1, 1, 1, 0.4)
        love.graphics.printf("DMG: " .. tower.damage, infoX + 145, infoY + 4, 100, "left")
        
        local cost = tower.level >= 10 and "MAX" or (20 * (2 ^ (tower.level - 1)))
        love.graphics.setColor(0.3, 0.9, 0.3, 0.6)
        love.graphics.printf("X: " .. cost .. "G", infoX + 255, infoY + 4, 100, "left")
        
        local sellPrice = math.floor(getTotalCost(tower) * 0.75)
        love.graphics.setColor(0.9, 0.3, 0.3, 0.6)
        love.graphics.printf("Y: " .. sellPrice .. "G", infoX + 365, infoY + 4, 100, "left")
        
        love.graphics.setColor(0.4, 0.4, 0.6, 0.5)
        if tower.sellConfirm then
            love.graphics.printf("Press Y again to confirm sell", infoX + 15, infoY + 35, 350, "left")
        else
            love.graphics.printf("X: Upgrade  |  Y: Sell  |  B: Cancel", infoX + 15, infoY + 35, 450, "left")
        end
        
    else
        love.graphics.setColor(0.4, 0.4, 0.6, 0.6)
        if isPathCell(cursor.col, cursor.row) then
            love.graphics.printf("PATH CELL - Build here to redirect enemies", infoX + 15, infoY + 20, 500, "left")
        else
            love.graphics.printf("Press A to build a tower here", infoX + 15, infoY + 20, 350, "left")
        end
    end
    
    -- Error message overlay
    if errorTimer > 0 then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 400, panelY + 25, 480, 35)
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.setFont(fontMedium)
        love.graphics.printf(errorMessage, 410, panelY + 30, 460, "center")
    end
end

-- ============================================
-- LOVE DRAW
-- ============================================
function love.draw()
    if gameState == "MENU" then
        drawMainMenu()
        if showControls then drawControlsOverlay() end
        return
    end
    
    drawGameArea()
    drawUIPanel()
    
    if showControls then drawControlsOverlay() end
end

-- ============================================
-- INPUT HANDLING
-- ============================================
function love.keypressed(key)
    if gameState == "MENU" then
        if key == "select" or key == "tab" then
            showControls = not showControls
            return
        end
        if showControls then return end
        if key == "a" or key == "return" or key == "space" then
            gameState = "PLAYING"
            stopMenuMusic()
            playGameMusic()
            gameStarted = true
            startWave()
            return
        end
        return
    end
    
    if key == "select" or key == "tab" then
        showControls = not showControls
        return
    end
    if showControls then return end
    if errorTimer > 0 then
        errorTimer = 0
        return
    end
    
    if key == "l" or key == "leftbracket" then
        speedIndex = math.max(1, speedIndex - 1)
        gameSpeed = speedLevels[speedIndex]
        return
    end
    if key == "r" or key == "rightbracket" then
        speedIndex = math.min(#speedLevels, speedIndex + 1)
        gameSpeed = speedLevels[speedIndex]
        return
    end
    
    if not gameStarted then
        if key == "a" or key == "return" or key == "space" then
            gameStarted = true
            startWave()
            return
        end
    end
    
    if state == "BUILDING" then
        if key == "left" or key == "a" then
            selectedTowerType = selectedTowerType - 1
            if selectedTowerType < 1 then selectedTowerType = #towerTypes end
            return
        end
        if key == "right" or key == "d" then
            selectedTowerType = selectedTowerType + 1
            if selectedTowerType > #towerTypes then selectedTowerType = 1 end
            return
        end
        if key == "b" or key == "backspace" then
            state = "MOVING"
            return
        end
        if key == "a" or key == "return" or key == "space" then
            local selected = towerTypes[selectedTowerType]
            if gold >= selected.cost then
                gridData[cursor.col][cursor.row] = {
                    type = selectedTowerType,
                    level = 1,
                    damage = selected.damage,
                    fireRate = selected.fireRate,
                    cooldown = 0,
                    color = selected.color,
                }
                
                local testPath = findPath()
                if testPath then
                    updatePath()
                    gold = gold - selected.cost
                    state = "MOVING"
                    playSound(sfx_build)
                else
                    gridData[cursor.col][cursor.row] = nil
                    showError("Path blocked!")
                end
            else
                showError("Not enough gold!")
            end
            return
        end
        return
    end
    
    local moved = false
    if key == "up" or key == "w" then
        cursor.row = math.max(1, cursor.row - 1)
        moved = true
    elseif key == "down" or key == "s" then
        cursor.row = math.min(grid.rows, cursor.row + 1)
        moved = true
    elseif key == "left" or key == "a" then
        cursor.col = math.max(1, cursor.col - 1)
        moved = true
    elseif key == "right" or key == "d" then
        cursor.col = math.min(grid.cols, cursor.col + 1)
        moved = true
    end
    
    if moved then
        if state == "TOWER_SELECTED" then
            state = "MOVING"
            local tower = gridData[cursor.col] and gridData[cursor.col][cursor.row]
            if tower then tower.sellConfirm = nil end
        end
        return
    end
    
    local tower = gridData[cursor.col] and gridData[cursor.col][cursor.row]
    
    if key == "a" or key == "return" or key == "space" then
        if state == "MOVING" then
            if tower then
                state = "TOWER_SELECTED"
            else
                state = "BUILDING"
            end
        end
        return
    end
    
    if key == "b" or key == "backspace" then
        if state == "TOWER_SELECTED" then
            state = "MOVING"
            if tower then tower.sellConfirm = nil end
        end
        return
    end
    
    if key == "x" and state == "TOWER_SELECTED" and tower then
        if tower.level >= 10 then
            showError("Max level reached!")
            return
        end
        local cost = 20 * (2 ^ (tower.level - 1))
        if gold >= cost then
            gold = gold - cost
            tower.level = tower.level + 1
            tower.damage = tower.damage * 2
            tower.fireRate = math.floor(tower.fireRate * 0.9 * 100) / 100
            state = "MOVING"
            playRandomUpgradeSound()
        else
            showError("Not enough gold!")
        end
        return
    end
    
    if key == "y" and state == "TOWER_SELECTED" and tower then
        if not tower.sellConfirm then
            tower.sellConfirm = true
        else
            local totalCost = getTotalCost(tower)
            local sellPrice = math.floor(totalCost * 0.75)
            gold = gold + sellPrice
            gridData[cursor.col][cursor.row] = nil
            updatePath()
            state = "MOVING"
            playSound(sfx_sell)
        end
        return
    end
end

-- ============================================
-- TOUCH SUPPORT (PS Vita)
-- ============================================
function love.touchpressed(id, x, y, dx, dy)
    if gameState == "MENU" then
        if x >= 570 and x <= 710 and y >= 400 and y <= 455 then
            gameState = "PLAYING"
            stopMenuMusic()
            playGameMusic()
            gameStarted = true
            startWave()
        end
        return
    end
    
    for col = 1, grid.cols do
        for row = 1, grid.rows do
            local gx = grid.offsetX + (col - 1) * grid.cellSize
            local gy = grid.offsetY + (row - 1) * grid.cellSize
            if x >= gx and x <= gx + grid.cellSize and
               y >= gy and y <= gy + grid.cellSize then
                cursor.col = col
                cursor.row = row
                love.keypressed("a")
                return
            end
        end
    end
end

-- ============================================
-- INITIALIZE - FORCE LARGE WINDOW HERE
-- ============================================
function love.load()
    -- FORCE the window to be 1280x720
    love.window.setMode(1280, 720, {
        resizable = false,
        fullscreen = false,
        minwidth = 1280,
        minheight = 720,
        centered = true
    })
    
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Scaled fonts for larger window
    fontTitle = love.graphics.newFont(36)
    fontLarge = love.graphics.newFont(26)
    fontMedium = love.graphics.newFont(18)
    fontSmall = love.graphics.newFont(14)
    fontTiny = love.graphics.newFont(11)
    
    love.graphics.setFont(fontMedium)
    
    loadSounds()
    playMenuMusic()
    spawnMenuParticles()
    
    math.randomseed(os.time())
end