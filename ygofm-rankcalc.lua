-- ============================================================
--  Yu-Gi-Oh! Forbidden Memories - A-Tec Rank Tracker
--  BizHawk Lua Script
-- ============================================================

local ADDR = {
    cards_used        = 0x0EA008,
    remaining_lp      = 0x0EA004,
    enemy_lp          = 0x0EA024,
    turns             = 0x0E9FF1,
    effective_attacks = 0x0E9FF2,
    face_down_plays   = 0x0E9FF4,
    initiate_fusion   = 0x0E9FF8,
    equip_magic       = 0x0E9FF9,
    pure_magic        = 0x0E9FF5,
    trigger_trap      = 0x0E9FF6,
}

-- A-Tec requirements
local REQ = {
    fusions      = 15,
    eff_atks     = 4,
    face_down    = 1,
    pure_magic   = 1,
    equip        = 1,
    trap         = 1,
    cards_used   = 37,
    turns_max    = 9,
    lp_max       = 6999,  -- must be UNDER 7000 (fail if >= 7000)
}

-- Score helpers
local function score_turns(t)
    if t <= 4 then return 12 elseif t <= 8 then return 8
    elseif t <= 28 then return 0 elseif t <= 32 then return -8
    else return -12 end
end
local function score_eff_atk(n)
    if n <= 1 then return 4 elseif n <= 3 then return 2
    elseif n <= 9 then return 0 elseif n <= 19 then return -2
    else return -4 end
end
local function score_face_down(n)
    if n == 0 then return 0 elseif n <= 10 then return -2
    elseif n <= 20 then return -4 elseif n <= 30 then return -6
    else return -8 end
end
local function score_fusion(n)
    if n == 0 then return 4 elseif n <= 4 then return 0
    elseif n <= 9 then return -4 elseif n <= 14 then return -8
    else return -12 end
end
local function score_equip(n)
    if n == 0 then return 4 elseif n <= 4 then return 0
    elseif n <= 9 then return -4 elseif n <= 14 then return -8
    else return -12 end
end
local function score_pure_magic(n)
    if n == 0 then return 2 elseif n <= 3 then return -4
    elseif n <= 6 then return -8 elseif n <= 9 then return -12
    else return -16 end
end
local function score_trap(n)
    if n == 0 then return 2 elseif n <= 2 then return -8
    elseif n <= 4 then return -16 elseif n <= 6 then return -24
    else return -32 end
end
local function score_cards(n)
    if n <= 8 then return 15 elseif n <= 12 then return 12
    elseif n <= 32 then return 0 elseif n <= 36 then return -5
    else return -7 end
end
local function score_lp(lp)
    if lp <= 99 then return -7 elseif lp <= 999 then return -5
    elseif lp <= 6999 then return 0 elseif lp <= 7999 then return 4
    else return 6 end
end

-- bad=red(+), ok=yellow(0), good=green(-)
local function score_color(s)
    if s > 0 then return 0xFFFF4444      -- red: bad
    elseif s == 0 then return 0xFFFFDD00 -- yellow: ok
    else return 0xFF33FF88               -- green: good
    end
end

local function read_values()
    local v = {}
    v.cards_used        = memory.read_u8(ADDR.cards_used)
    v.remaining_lp      = memory.read_u16_le(ADDR.remaining_lp)
    v.enemy_lp          = memory.read_u16_le(ADDR.enemy_lp)
    v.turns             = memory.read_u8(ADDR.turns)
    v.effective_attacks = memory.read_u8(ADDR.effective_attacks)
    v.fusions           = memory.read_u8(ADDR.initiate_fusion)
    v.equip_magic       = memory.read_u8(ADDR.equip_magic)
    v.pure_magic        = memory.read_u8(ADDR.pure_magic)
    v.trigger_trap      = memory.read_u8(ADDR.trigger_trap)
    v.face_down_plays   = memory.read_u8(ADDR.face_down_plays)
    return v
end

local function check_atec(v)
    local c = {}
    c.fusions    = v.fusions           >= REQ.fusions
    c.eff_atks   = v.effective_attacks >= REQ.eff_atks
    c.face_down  = v.face_down_plays   >= REQ.face_down
    c.pure_magic = v.pure_magic        >= REQ.pure_magic
    c.equip      = v.equip_magic       >= REQ.equip
    c.trap       = v.trigger_trap      >= REQ.trap
    c.cards_used = v.cards_used        >= REQ.cards_used
    c.turns      = v.turns >= 9
    c.lp         = v.remaining_lp      <  7000   -- strictly under 7000
    local all = true
    for _, ok in pairs(c) do if not ok then all = false; break end end
    return c, all
end

-- Drawing
local FONT   = "Arial"
local FONT_SZ= 8
local LINE_H = 9
local PAD    = 3
local COL_MARK  = PAD
local COL_LABEL = PAD + 18
local COL_VAL   = PAD + 100
local OX, OY = 0, 0
local details_visible = true

local C = {
    bg       = 0xFF05050F,
    border   = 0xFF2222AA,
    title_bg = 0xFF0A0A40,
    title    = 0xFFFFD700,
    ok       = 0xFF33FF88,
    fail     = 0xFFFF4444,
    label    = 0xFFDDDDDD,
    sep      = 0xFF333355,
    score_p  = 0xFF44FFAA,
    score_n  = 0xFFFF6666,
    atec_bg  = 0xFF003B00,
    atec_txt = 0xFF00FF55,
    no_bg    = 0xFF3B0000,
    no_txt   = 0xFFFF3333,
}

local function draw_overlay()
    local v = read_values()
    local c, all_met = check_atec(v)

    local rows = {
        { label="Fusions",      val=v.fusions,           req=REQ.fusions,   ok=c.fusions,    fmt="%d/%d", sc=score_fusion(v.fusions)        },
        { label="Eff. Attacks", val=v.effective_attacks, req=REQ.eff_atks,  ok=c.eff_atks,   fmt="%d/%d", sc=score_eff_atk(v.effective_attacks) },
        { label="Face Down",    val=v.face_down_plays,   req=REQ.face_down, ok=c.face_down,  fmt="%d/%d", sc=score_face_down(v.face_down_plays)  },
        { label="Pure Magic",   val=v.pure_magic,        req=REQ.pure_magic,ok=c.pure_magic, fmt="%d/%d", sc=score_pure_magic(v.pure_magic)      },
        { label="Equip Magic",  val=v.equip_magic,       req=REQ.equip,     ok=c.equip,      fmt="%d/%d", sc=score_equip(v.equip_magic)          },
        { label="Trap",         val=v.trigger_trap,      req=REQ.trap,      ok=c.trap,       fmt="%d/%d", sc=score_trap(v.trigger_trap)          },
        { label="Cards Used",   val=v.cards_used,        req=REQ.cards_used,ok=c.cards_used, fmt="%d/%d", sc=score_cards(v.cards_used)           },
        { label="Turns",        val=v.turns,             req=REQ.turns_max, ok=c.turns,      fmt="%d",    sc=score_turns(v.turns)                },
        { label="LP",           val=v.remaining_lp,      req=6999,          ok=c.lp,         fmt="%d",    sc=score_lp(v.remaining_lp)            },
    }

    -- Score (always calculated)
    local total_score = 50
                      + score_turns(v.turns)
                      + score_eff_atk(v.effective_attacks)
                      + score_face_down(v.face_down_plays)
                      + score_fusion(v.fusions)
                      + score_equip(v.equip_magic)
                      + score_pure_magic(v.pure_magic)
                      + score_trap(v.trigger_trap)
                      + score_cards(v.cards_used)
                      + score_lp(v.remaining_lp)
                      + (v.enemy_lp == 0 and 2 or 0)

    local function get_rank(s)
        if     s >= 90 then return "S POW", 0xFFFF4466
        elseif s >= 80 then return "A POW", 0xFFFF8844
        elseif s >= 70 then return "B POW", 0xFFFFAA22
        elseif s >= 60 then return "C POW", 0xFFFFCC00
        elseif s >= 50 then return "D POW", 0xFFFFDD66
        elseif s >= 40 then return "D TEC", 0xFFAADDFF
        elseif s >= 30 then return "C TEC", 0xFF66CCFF
        elseif s >= 20 then return "B TEC", 0xFF33AAFF
        elseif s >= 10 then return "A TEC", 0xFF0088FF
        else                return "S TEC", 0xFF00FFFF
        end
    end
    local rank_label, rank_clr = get_rank(total_score)

    local W       = 125
    local title_h = LINE_H + 2
    local sep_h   = 3
    local score_h = LINE_H * 2
    local body_h  = details_visible and (#rows * LINE_H + sep_h) or 0
    local atec_h  = (details_visible and all_met) and LINE_H or 0
    local total_h = title_h + 2 + body_h + score_h + 2 + atec_h

    gui.drawRectangle(OX, OY, W, total_h, C.border, C.bg)
    gui.drawRectangle(OX, OY, W, title_h, C.title_bg, C.title_bg)
    gui.pixelText(OX + PAD, OY + 3, "Tracker [YGO FM] by Buzchy", C.title, 0x00000000)

    local y = OY + title_h + 2

    if details_visible then
        for _, row in ipairs(rows) do
            local mark     = row.ok and "OK" or "--"
            local mark_clr = row.ok and C.ok or C.fail
            local val_clr  = score_color(row.sc)
            local val_str  = string.format(row.fmt, row.val, row.req)

            gui.pixelText(OX + COL_MARK,  y, mark,      mark_clr, 0x00000000)
            gui.pixelText(OX + COL_LABEL, y, row.label, C.label,  0x00000000)
            gui.pixelText(OX + COL_VAL,   y, val_str,   val_clr,  0x00000000)
            y = y + LINE_H
        end

        y = y + 1
        gui.drawLine(OX + 4, y, OX + W - 4, y, C.sep)
        y = y + sep_h
    end

    -- Score + Rank always visible
    local sc_clr = total_score >= 0 and C.score_p or C.score_n
    local sc_str = total_score >= 0 and ("Score: +" .. total_score) or ("Score: " .. total_score)
    gui.pixelText(OX + PAD, y, sc_str, sc_clr, 0x00000000)
    y = y + LINE_H
    gui.pixelText(OX + PAD, y, "Rank:  " .. rank_label, rank_clr, 0x00000000)

    -- A-TEC COMPLETE banner only when all met and details visible
    if details_visible and all_met then
        y = y + LINE_H
        gui.drawRectangle(OX, y, W, LINE_H, C.atec_bg, C.atec_bg)
        gui.pixelText(OX + 10, y + 2, "*** A-TEC COMPLETE! ***", C.atec_txt, 0x00000000)
    end
end

local prev_backspace = false

event.onframeend(function()
    local keys = input.get()
    local cur_backspace = keys["Backspace"]

    if cur_backspace and not prev_backspace then
        details_visible = not details_visible
        gui.clearGraphics()
    end
    prev_backspace = cur_backspace

    draw_overlay()
end)

event.onexit(function()
    gui.clearGraphics()
end)

print("[A-Tec Tracker] Loaded OK.")
