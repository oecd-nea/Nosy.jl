import Dates

"""
Functions to return the hour / day / month in function of the hourly time series index.

NB: there is a 1 unit difference between the time series index (starts at 1) and hour (starts at 0).
"""


# return a DateTime from time series (=hour-1) index and year (default 2023)
_dt(i::Int, y::Int) = Dates.DateTime(y) + Dates.Hour(i-1)

# return a hour (0:8759) from hour index (1:8760)
_hour(i::Int, ::Int=2023) = Dates.Hour(i-1).value

# return a day number (1:365 or so) from hour index (1:8760)
_day(i::Int, y::Int=2023) = Dates.days(_dt(i,y) - _dt(1,y)) +1

# return a month number (1:12) from hour index (1:8760)
_month(i::Int, y::Int=2023) = (Dates.month(_dt(i,y)))