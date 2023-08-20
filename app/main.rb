@__init_not_ran = true

def init(args)
  @__init_not_ran = false

  @base_enemy_spawn_rate = 90
  @enemy_spawn_cooldown = @base_enemy_spawn_rate
  @current_enemy_spawn_cooldown = @enemy_spawn_cooldown
  @player_state = 0
  @prev_player_state = 0
  @fh = 70
  @fl = 100
  @player = {
    x: 640,
    y: 360,
    w: 24,
    h: 48,
    path: :player,
    vx: 0,
    vy: 0,
    hp: 10,
    base_movement_speed: 5,
    anchor_x: 0.5,
    anchor_y: 0.5,
    base_dash_cooldown: 120,
    current_dash_cooldown: 0,
    base_dash_length: 200,
    base_shoot_cooldown: 20,
    current_shoot_cooldown: 0,
    base_bullet_lifetime: 600,
    base_bullet_speed: 10,
    base_bullet_size: 8
  }

  @player[:dash_cooldown] = @player[:base_dash_cooldown]
  @player[:movement_speed] = @player[:base_movement_speed]
  @player[:dash_length] = @player[:base_dash_length]
  @player[:shoot_cooldown] = @player[:base_shoot_cooldown]
  @player[:bullet_lifetime] = @player[:base_bullet_lifetime]
  @player[:bullet_speed] = @player[:base_bullet_speed]
  @player[:bullet_size] = @player[:base_bullet_size]

  @resolvable_player_bullets = []
  @player_bullets = []
  @enemies = []

  @default_player_color = {
    r: 0,
    g: 0xff,
    b: 0
  }

  @dashing_player_color = {
    r: 0,
    g: 0xff,
    b: 0x7f
  }

  @dashless_player_color = {
    r: 0,
    g: 0x7f,
    b: 0
  }

  @player_state_merge_modifiers = [
    @default_player_color,
    @dashing_player_color,
    @dashing_player_color,
    @dashless_player_color
  ]

  @aim_sight = {
    x: 640,
    y: 360,
    x2: 640,
    y2: 360,
    r: 0xca,
    g: 0xca,
    b: 0xca,
    a: 0x7f
  }

  prt = args.outputs[:player]
  prt.w = 32
  prt.h = 64
  prt.primitives << {
    x: 0,
    y: 0,
    w: 32,
    h: 64,
    path: :pixel
  }

  @mouse_right_lt = false
end

def reset
  @__init_not_ran = true
end

def _process_inputs(inputs)
  key_held = inputs.keyboard.key_held
  mouse = inputs.mouse
  player = @player
  vx = 0
  vy = 0

  if @player_state == 0 || @player_state == 3
    vy += 1 if key_held.w
    vy -= 1 if key_held.s
    vx -= 1 if key_held.a
    vx += 1 if key_held.d

    unless vy == 0 || vx == 0
      sqrt2 = 2**0.5
      vy /= sqrt2
      vx /= sqrt2
    end

    ms = player.movement_speed
    player.vx += vx * ms
    player.vy += vy * ms

    @aim_sight.x2 = mouse.x
    @aim_sight.y2 = mouse.y

    @player_state = 0 if player.current_dash_cooldown <= 0

    if mouse.button_right && @player_state == 0
      @prev_player_state = @player_state
      @player_state = 1
      player.current_dash_cooldown = player.dash_cooldown
    end

    if mouse.button_left && player.current_shoot_cooldown <= 0
      player[:current_shoot_cooldown] = player[:shoot_cooldown]
      @resolvable_player_bullets << {
        lifetime: player[:bullet_lifetime],
        pierce: 5,
        w: player[:bullet_size],
        h: player[:bullet_size],
        anchor_x: 0.5,
        anchor_y: 0.5,
        path: :pixel,
        damage: 2
      }
    end
  elsif @player_state == 1
    player.svx = player.vx.abs
    player.svy = player.vy.abs
    ifhl = (@fh / @fl)

    m = Math
    asa = @aim_sight.angle
    pdl = @player.dash_length
    dx = m.cos(asa) * pdl
    dy = m.sin(asa) * pdl

    asdxh = dx * ifhl
    asdyh = dy * ifhl

    player.vx += asdxh
    player.vy += asdyh
    @player_state = 2
  elsif @player_state == 2
    @player_state = 3 if player.vx.abs <= player.svx || player.vy.abs <= player.svy
  end
end

def enemy_make
  {
    x: rand(36) - (rand < 0.5 ? 48 : -1292),
    y: rand(72) - (rand < 0.5 ? 96 : -744),
    w: 24,
    h: 48,
    path: :pixel,
    r: 0xff,
    g: 0,
    b: 0,
    anchor_x: 0.5,
    anchor_y: 0.5,
    ms: 4,
    hp: 3,
    iframes: 0
  }
end

def _calc(_args)
  math = Math

  player = @player
  player.vx = (player.vx * @fh).truncate / @fl
  player.vy = (player.vy * @fh).truncate / @fl
  px = player.x += player.vx
  py = player.y += player.vy
  asx = @aim_sight.x = player.x
  axy = @aim_sight.y = player.y

  player.current_dash_cooldown -= 1
  player.current_shoot_cooldown -= 1
  @current_enemy_spawn_cooldown -= 1

  @player_bullets.each do |bullet|
    bullet[:lifetime] -= 1
    bullet[:x] += bullet[:vx]
    bullet[:y] += bullet[:vy]
  end
  @player_bullets.reject! do |bullet|
    bullet[:lifetime] < 0 || bullet.pierce <= 0
  end

  asdx = @aim_sight.dx = @aim_sight.x2 - @aim_sight.x
  asdy = @aim_sight.dy = @aim_sight.y2 - @aim_sight.y
  asa = @aim_sight.angle = math.atan2(asdy, asdx)
  asd2 = @aim_sight.distance2 = asdx * asdx + asdy * asdy

  while (rb = @resolvable_player_bullets.pop)
    @player_bullets << rb.merge(
      x: player.x,
      y: player.y,
      vx: math.cos(asa) * player[:bullet_speed],
      vy: math.sin(asa) * player[:bullet_speed]
    )
  end

  if @current_enemy_spawn_cooldown <= 0
    @enemies << enemy_make
    @current_enemy_spawn_cooldown = @enemy_spawn_cooldown
  end

  @enemies.each do |enemy|
    epdx = player.x - enemy.x
    epdy = player.y - enemy.y
    isql = enemy.ms / ((epdx * epdx + epdy * epdy)**0.5)
    enemy.x += epdx * isql
    enemy.y += epdy * isql
    @player_bullets.each do |bullet|
      next unless enemy.iframes <= 0 && bullet.pierce > 0 && bullet.intersect_rect?(enemy)

      enemy.iframes = 2
      enemy.hit = true
      enemy.hp -= bullet.damage
      bullet.pierce -= 1
    end
    enemy.iframes -= 1
  end

  @enemies.reject! do |enemy|
    enemy.hit = false
    enemy.hp <= 0
  end

  @player_bullets.reject! do |bullet|
  end
  1
end

def _render(outputs)
  outputs.background_color = {
    r: 0x23, g: 0x23, b: 0x32
  }

  outputs.primitives << [@aim_sight, @enemies, @player.merge(@player_state_merge_modifiers[@player_state]),
                         @player_bullets]
end

def tick(args)
  init(args) if @__init_not_ran
  _process_inputs(args.inputs)
  _calc(args)
  _render(args.outputs)
end
