local _ = ...

-- palettes only hold colours; style tokens (radius, font, transparency, ...) live in Core/Theme
local rgb = Color3.fromRGB

local function palette(p)
    return {
        Accent = p.Accent,
        AccentAlt = p.AccentAlt,
        Background = p.Background,
        BackgroundAlt = p.BackgroundAlt,
        Surface = p.Surface,
        SurfaceHover = p.SurfaceHover,
        Elevated = p.Elevated,
        ElevatedHover = p.ElevatedHover,
        Stroke = p.Stroke,
        Divider = p.Divider,
        Text = p.Text or rgb(232, 233, 240),
        TextDim = p.TextDim or rgb(152, 154, 168),
        TextMuted = p.TextMuted or rgb(98, 100, 114),
        OnAccent = p.OnAccent or rgb(255, 255, 255),
        Success = p.Success or rgb(74, 200, 122),
        Warning = p.Warning or rgb(244, 182, 62),
        Danger = p.Danger or rgb(236, 88, 88),
        Info = p.Info or rgb(88, 166, 255),
    }
end

return {
    Order = { "Sapphire", "Obsidian", "Midnight", "Ocean", "Emerald", "Amber", "Crimson", "Rose", "Paper", "Violet" },

    Sapphire = palette({
        Accent = rgb(78, 132, 255), AccentAlt = rgb(140, 205, 255),
        Background = rgb(6, 6, 9), BackgroundAlt = rgb(36, 38, 46),
        Surface = rgb(12, 12, 16), SurfaceHover = rgb(20, 20, 26),
        Elevated = rgb(24, 25, 32), ElevatedHover = rgb(33, 34, 43),
        Stroke = rgb(88, 92, 110), Divider = rgb(52, 54, 66),
    }),

    Obsidian = palette({
        Accent = rgb(222, 222, 228), AccentAlt = rgb(120, 120, 130),
        Background = rgb(5, 5, 6), BackgroundAlt = rgb(48, 48, 52),
        Surface = rgb(11, 11, 12), SurfaceHover = rgb(20, 20, 22),
        Elevated = rgb(24, 24, 27), ElevatedHover = rgb(34, 34, 38),
        Stroke = rgb(92, 92, 100), Divider = rgb(55, 55, 60),
        OnAccent = rgb(12, 12, 14),
    }),

    Midnight = palette({
        Accent = rgb(146, 112, 255), AccentAlt = rgb(206, 172, 255),
        Background = rgb(8, 7, 14), BackgroundAlt = rgb(34, 26, 58),
        Surface = rgb(14, 12, 24), SurfaceHover = rgb(22, 19, 36),
        Elevated = rgb(27, 23, 44), ElevatedHover = rgb(37, 32, 58),
        Stroke = rgb(96, 84, 140), Divider = rgb(55, 48, 84),
        Text = rgb(236, 232, 248), TextDim = rgb(160, 152, 186), TextMuted = rgb(104, 97, 132),
    }),

    Ocean = palette({
        Accent = rgb(38, 192, 232), AccentAlt = rgb(132, 232, 255),
        Background = rgb(4, 8, 11), BackgroundAlt = rgb(16, 36, 48),
        Surface = rgb(9, 14, 18), SurfaceHover = rgb(14, 22, 28),
        Elevated = rgb(18, 28, 36), ElevatedHover = rgb(26, 40, 50),
        Stroke = rgb(64, 104, 120), Divider = rgb(38, 62, 72),
        OnAccent = rgb(4, 14, 18),
    }),

    Emerald = palette({
        Accent = rgb(46, 204, 133), AccentAlt = rgb(120, 240, 186),
        Background = rgb(5, 9, 8), BackgroundAlt = rgb(18, 42, 34),
        Surface = rgb(10, 15, 13), SurfaceHover = rgb(16, 24, 20),
        Elevated = rgb(20, 32, 27), ElevatedHover = rgb(28, 44, 37),
        Stroke = rgb(64, 112, 92), Divider = rgb(38, 66, 54),
        OnAccent = rgb(4, 20, 13),
    }),

    Amber = palette({
        Accent = rgb(245, 176, 46), AccentAlt = rgb(255, 214, 132),
        Background = rgb(9, 7, 4), BackgroundAlt = rgb(48, 37, 18),
        Surface = rgb(15, 13, 9), SurfaceHover = rgb(24, 20, 13),
        Elevated = rgb(32, 27, 18), ElevatedHover = rgb(44, 37, 24),
        Stroke = rgb(116, 96, 56), Divider = rgb(66, 55, 34),
        OnAccent = rgb(20, 13, 2),
    }),

    Crimson = palette({
        Accent = rgb(236, 88, 88), AccentAlt = rgb(255, 150, 150),
        Background = rgb(9, 4, 5), BackgroundAlt = rgb(52, 20, 22),
        Surface = rgb(15, 9, 10), SurfaceHover = rgb(25, 14, 16),
        Elevated = rgb(34, 20, 22), ElevatedHover = rgb(46, 27, 30),
        Stroke = rgb(122, 62, 64), Divider = rgb(70, 38, 40),
    }),

    Rose = palette({
        Accent = rgb(247, 132, 178), AccentAlt = rgb(255, 190, 216),
        Background = rgb(10, 6, 8), BackgroundAlt = rgb(48, 26, 36),
        Surface = rgb(16, 10, 13), SurfaceHover = rgb(26, 16, 21),
        Elevated = rgb(35, 22, 28), ElevatedHover = rgb(47, 30, 38),
        Stroke = rgb(118, 74, 90), Divider = rgb(68, 44, 53),
        OnAccent = rgb(24, 6, 13),
    }),

    Paper = palette({
        Accent = rgb(64, 110, 240), AccentAlt = rgb(120, 160, 255),
        Background = rgb(238, 239, 244), BackgroundAlt = rgb(210, 216, 232),
        Surface = rgb(248, 249, 252), SurfaceHover = rgb(236, 238, 245),
        Elevated = rgb(229, 232, 240), ElevatedHover = rgb(220, 224, 235),
        Stroke = rgb(160, 166, 184), Divider = rgb(206, 210, 222),
        Text = rgb(28, 30, 38), TextDim = rgb(94, 98, 112), TextMuted = rgb(138, 142, 158),
        OnAccent = rgb(255, 255, 255),
    }),

    Violet = palette({
        Accent = rgb(186, 104, 255), AccentAlt = rgb(228, 160, 255),
        Background = rgb(7, 5, 12), BackgroundAlt = rgb(40, 22, 62),
        Surface = rgb(13, 10, 20), SurfaceHover = rgb(21, 16, 31),
        Elevated = rgb(30, 22, 44), ElevatedHover = rgb(40, 30, 58),
        Stroke = rgb(104, 74, 142), Divider = rgb(60, 44, 82),
    }),
}
