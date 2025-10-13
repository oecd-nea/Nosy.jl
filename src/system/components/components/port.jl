"""
Accessing ports of components.
"""

# return the port structure of a Component
portstructure(c::Component) = c.s

# return the port with name pname of a component
getport(c::Component, pname::String) = _getport(portstructure(c), pname, name(c))

# return the port with name pname of a component, hint on sense makes the call faster
getport(c::Component, pname::String, sense::Symbol) = _getport(portstructure(c), pname, name(c), sense)

# return true if all the ports of the component are used
# return false otherwise
isfullyconnected(c::Component) = isfullyconnected(portstructure(c))