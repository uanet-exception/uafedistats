# We need this to make the script work on some versions of gnuplot
set term dumb
set fit quiet
set fit logfile '/dev/null'
set out "/dev/null"
set print "-"

# derivative functions.  Return 1/0 for first point, otherwise delta y or (delta y)/(delta x)
max(x, y) = x > y ? x : y
d(y) = ($0 == 0) ? (y1 = y, 1/0) : (y2 = y1, y1 = y, max(y1-y2, 0))
d_smooth(y, extreme_y) = ($0 == 0) ? (y1 = y, 1/0) : (y2 = y1, y1 = y, y1-y2 > extreme_y ? 0 : max(y1-y2, 0))

# Set length of time for the entire graph
day = 24*60*60
week = 7*day
start_time = time(0) - week

# Set tic width
tic_width = (time(0) - start_time) / 7

# We're going to be using comma-separated values, so set this up
set datafile separator ","

# 'Pre-plot' the two charts "invisibly" first, to get the bounds of the data
# Interestingly, if you have your terminal set up with 'sixel' output, that's where they'll appear! Neato.

# Set pre-plot settings common to each plot
set xrange [start_time:]

# Plot 'usercount' of the past week and get bounds (for GRAPH 1 y1)
plot "workspace/mastostats.csv" using 1:2
#usercountlow = 0
usercountlow = GPVAL_DATA_Y_MIN - (GPVAL_DATA_Y_MAX - GPVAL_DATA_Y_MIN)
usercounthigh = GPVAL_DATA_Y_MAX

f(x) = uc_mean
fit f(x) "workspace/mastostats.csv" using ($1):(d($2)) via uc_mean
uc_extreme = uc_mean * 50

plot "workspace/mastostats.csv" using ($1):(d($2))
print "Usercount mean            : ",uc_mean
print "Usercount extreme         : ",uc_extreme
print "Usercount max wo smooth   : ",GPVAL_DATA_Y_MAX

# Plot derivative of 'usercount' of the past week and get bounds (for GRAPH 1 y2)
plot "workspace/mastostats.csv" using ($1):(d_smooth($2, uc_extreme))
uc_derivative_low = GPVAL_DATA_Y_MIN
uc_derivative_high = GPVAL_DATA_Y_MAX
print "Usercount max with smooth : ",GPVAL_DATA_Y_MAX

# Plot derivative of 'instancecount' of the past week and get bounds (for GRAPH 2 y1)
plot "workspace/mastostats.csv" using 1:3
instanceslow  = GPVAL_DATA_Y_MIN
instanceshigh = GPVAL_DATA_Y_MAX

f(x) = tc_mean
fit f(x) "workspace/mastostats.csv" using ($1):(d($4)) via tc_mean
tc_extreme = tc_mean * 50

plot "workspace/mastostats.csv" using ($1):(d($4))
print "Tootscount mean           : ",tc_mean
print "Tootscount extreme        : ",tc_extreme
print "Tootscount max wo smooth  : ",GPVAL_DATA_Y_MAX

# Plot derivative of 'usercount' of the past week and get bounds (for GRAPH 1 y2)
plot "workspace/mastostats.csv" using ($1):(d_smooth($4, tc_extreme))
tc_derivative_low = GPVAL_DATA_Y_MIN
tc_derivative_high = GPVAL_DATA_Y_MAX
print "Tootscount max with smooth: ",GPVAL_DATA_Y_MAX

###############################################################################
# SETUP
###############################################################################

# Set up our fonts and such
set terminal png truecolor size 1464,660 enhanced font "branding/LiberationSans-Regular.ttf" 16 background rgb "#282d37"
set output 'workspace/graph.png'

# Set border colour and line width
set border lw 3 lc rgb "white"

# Set colours of the tics
set xtics textcolor rgb "white"
set ytics textcolor rgb "white"

# Set text colors of labels
set xlabel "X" textcolor rgb "white"
set ylabel "Y" textcolor rgb "white"

# Set the text colour of the key
set key textcolor rgb "white"

# Draw tics after the other elements, so they're not overlapped
set tics front

# Set layout into multiplot mode (2 rows by 1 column = 2 plots)
set multiplot layout 2, 1

# Make sure we don't draw tics on the opposite side of the graph
set xtics nomirror
set ytics nomirror



# Set margin sizes
tmarg = 1       # Top margin
cmarg = 0       # Centre margin
bmarg = 2.5     # Bottom margin

lmarg = 12      # Left margin
rmarg = 12       # Right margin



###############################################################################
# GRAPH 1 
# Current usercount & the derivative (rate of new users joining) (last 7 days)
###############################################################################

# Set top graph margins
set tmargin tmarg
set lmargin lmarg
set rmargin rmarg

# Set Y axis
set yrange [usercountlow:usercounthigh]
set ylabel "Number of users" textcolor rgb "#93ddff" offset 2,0,0
set decimalsign locale 'C.UTF-8'
set format y "%'.0f"

# Set Y2 axis
set y2range [0:uc_derivative_high * 1.2]
set y2label 'Hourly increase' textcolor rgb "#7ae9d8"
set y2tics textcolor rgb "white"
set format y2 "%'.0f"

# Set X axis
set xdata time
set xrange [start_time:]
set timefmt "%s"
set xlabel ""
set autoscale xfix

# Make the tics invisible, but continue to show the grid
set tics scale 0
set xtics tic_width
set format x ""


# Overall graph style
set style line 12 lc rgb "#FEFEFE" lt 1 lw 5
set grid

# Plot the graph
plot "workspace/mastostats.csv" every ::1 using 1:2 w filledcurves x1 title '' fs transparent solid 0.7 lc rgb "#2e85ad", \
        '' u ($1):(d_smooth($2, uc_extreme)) w filledcurves x1 title '' axes x1y2 fs transparent solid 0.5 noborder lc rgb "#7ae9d8"



###############################################################################
# GRAPH 2
# Number of instances
###############################################################################

# Set bottom graph margins
set tmargin cmarg
set bmargin bmarg
set lmargin lmarg
set rmargin rmarg

# Set Y axis
set yrange [instanceslow-(instanceshigh-instanceslow):instanceshigh]
set ylabel "Active instances" textcolor rgb "#E9967A" offset 1,0,0

# Set Y2 axis
set y2range [0:tc_derivative_high * 1.2/1e3]
set y2label 'Thousand toots per hour' textcolor rgb "#EEE8AA"
set format y2 "%'.0f"

# Set X axis
set xdata time 
set xrange [start_time:]
set timefmt "%s"
set format x "%a\n%d %b"
set xtics tic_width

# Overall graph style
set style line 12 lc rgb "#FEFEFE" lt 1 lw 5
set grid

# Plot the graph
plot "workspace/mastostats.csv" every ::1 using 1:3 w filledcurves x1 title '' fs transparent solid 0.7 lc rgb "#E9967A", \
        '' u ($1):(d_smooth($4, tc_extreme)/1e3) w filledcurves x1 title '' axes x1y2 fs transparent solid 0.5 noborder lc rgb "#EEE8AA"


# I think this needs to be here for some reason
unset multiplot
