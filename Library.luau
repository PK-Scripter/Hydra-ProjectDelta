local Library = {}

Library.NewObject = function(InstanceType, Properties, Parent)
    if not InstanceType then return end
    if not Parent then Parent = nil end
    local Object = Instance.new(InstanceType)
    if Properties then
        for i, v in pairs(Properties) do
            Object[i] = v
        end
    end
    
    if Parent then
        Object.Parent = Parent
    end
    
    return Object
end

Library.GetProperties = function(Instance)
    if not Instance then return end
    local Properties = {}
    for i, v in pairs(Instance) do
        Properties[i] = v
    end
    return Properties
end

Library.SetProperties = function(Instance, Properties)
    if not Instance or not Properties then return end
    for i, v in pairs(Properties) do
        Instance[i] = v
    end
end

return Library