"""
Accessing ports of components.
"""

# return the port structure of a Component
portstructure(c::Component) = c.s

# return the port with name pname of a component
getport(c::Component, pname::String) = getport(portstructure(c), pname)