"""
Accessing ports of components.
"""

# return the port structure of a Component
portstructure(c::Component) = portstructure(model(c)) # TODO: update after joint flow implementation

# return the port with name pname of a component
getport(c::Component, pname::String) = getport(portstructure(c), pname)