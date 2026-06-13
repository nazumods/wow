---@meta types

---@class string
---@field gmatch fun(self: string, pattern: string): boolean

---@class FontString
---@field SetFont fun(self: FontString, path: string, size: number, flags?: string)
---@field SetText fun(self: FontString, text: string)
---@field GetStringWidth fun(self: FontString): number