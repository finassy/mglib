MODULE mg_flow
DESCRIPTION Flow visualization
VERSION 1.0
SOURCE mgalloy
BUILD_DATE Apr 7 2008

#+
# Compute the line integral convolution for a vector field.
#
# :Returns:
#    `bytarr(m, n)`
#
# :Params:
#    u : in, required, type="fltarr(m, n), dblarr(m, n)"
#       x-coordinates of vector field
#    v : in, required, type="fltarr(m, n), dblarr(m, n)"
#       y-coordinates of vector field
#
# :Keywords:
#    texture : in, optional, type="bytarr(m, n)"
#       random texture map; it is useful to use the same texture map when
#       generating the frames of a animation
#-
FUNCTION MG_LIC 2 2 KEYWORDS
