local Font = require("ui/font")
for k, v in pairs(Font.fontmap) do
    if v == "NotoSans-Regular.ttf" then
        Font.fontmap[k] = "KGFirstTimeInForever.otf"
    elseif v == "NotoSans-Bold.ttf" then
        Font.fontmap[k] = "KGFirstTimeInForever.otf"
    end
end
