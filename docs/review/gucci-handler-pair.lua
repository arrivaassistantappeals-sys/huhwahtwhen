-- Replace BOTH orphaned task.defer blocks with this COMPLETE pair.
-- Paste inside each Gucci setup variant, between flag14 = false and now3 = os.clock().
table.insert(v27.Connections, seat.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or child.Name ~= "SeatWeld" then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == seat then
            child.Enabled = false
            child:Destroy()
            flag14 = true
        end
    end)
end))

table.insert(v27.Connections, v24.ChildAdded:Connect(function(child)
    if tbl16 ~= v27 or not child:IsA("LocalScript")
        or not child.Name:lower():find("control") then return end
    task.defer(function()
        if tbl16 == v27 and tbl8.GucciAntiGrab
            and localPlayer.Character == v24 and child.Parent == v24 then
            child.Enabled = false
            child:Destroy()
        end
    end)
end))
