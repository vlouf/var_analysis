#!/bin/ksh
#
# This script converts gridded radar rain data into NetCDF. It is not very efficient, but since it is only
# used once, this is not of great importance.
#
# Tim Hume.
# 18 July 2006.

export PATH=/bin:/usr/bin:/opt/local/bin:/usr/local/bin:/opt/netcdf3.6.2-ifort10.1.015/bin
export TZ=UTC

#
# Read the command line.
#

while [[ $# -gt 1 ]]
do
	case "${1}" in
		( "-I" | "-i" )
		infile=${2:-""}
		shift; shift
		;;
		( "-O" | "-o" )
		outfile=${2:-""}
		shift; shift
		;;
		( * )
		echo "E: No such option: ${1}"
		exit 2
		;;
	esac
done

if [[ ! -f "${infile}" ]]
then
	echo "E: No such input file: ${infile}"
	exit 1
fi
echo ${infile} ${outfile}
#
# Read the header lines.
#
set -A header_1 -- $(head -n1 "${infile}")
set -A header_2 -- $(head -n2 "${infile}" | tail -1l)

echo ${header_1[*]}

#
# Create the CDL, and then convert it to NetCDF using ncgen.
#
echo "netcdf radar {

dimensions:
	i = ${header_2[4]};
	j = ${header_2[7]};
	time = unlimited;
	
variables:
	float	lat(i,j);
			lat:units = \"degrees_north\";
			lat:long_name = \"latitude\";
			lat:_FillValue = -999.99f;
	float	lon(i,j);
			lon:units = \"degrees_east\";
			lon:long_name = \"longitude\";
			lon:_FillValue = -999.99f;
	float	rain_rate(time,i,j);
			rain_rate:long_name=\"rain rate\";
			rain_rate:units = \"mm/hour\";
			rain_rate:missing_value = -99.99f;
			rain_rate:_FillValue = -99.99f;
	int		time(time);
			time:long_name=\"time of radar scan\";
			time:units=\"seconds since 1970-01-01 00:00:00Z\";

data:
	//
	// The following awk job extracts the rain rate data, and puts it into CDL format.
	//
    rain_rate = $(sed -n '3,$'p ${infile}|paste -d, -s  |sed -e 's/ /,/g;s/,,/,/g;1s/^.//;$s/$/;/;s/,,/,/g')

	//
	// Convert the time to seconds since 1970-01-01 00:00:00 UTC
	//
	time = $(date -u -d "${header_1[0]} ${header_1[1]}" +%s);

	//
	// The following awk job calculates the latitude and longitude of each grid point.
	// We assume the radar domain is on a flat earth ... this should be OK for the rather
	// small domain.
	//
	$(awk -v lon=${header_2[1]} \
		-v lat=${header_2[0]} \
		-v xmin=${header_2[2]} -v dx=${header_2[8]} -v nx=${header_2[4]} \
		-v ymin=${header_2[5]} -v dy=${header_2[8]} -v ny=${header_2[7]} \
		'BEGIN{
			re = 6378;
			printf("lat = ");
			for (jj=0; jj<ny; ++jj){
				for (ii=0; ii<nx; ++ii){
					latg = lat + (ymin + jj*dy)*180/(re*3.14159265);
					if ((jj == (ny-1))&&(ii == (nx-1))){
						printf("%f;\n",latg);
					} else {
						printf("%f,",latg);
					}
				}
			}
			printf("lon = ");
			for (jj=0; jj<ny; ++jj){
				for (ii=0; ii<nx; ++ii){
					long = lon + (xmin + ii*dx)*180/(re*3.14159265*cos(lat*3.14159265/180));
					if ((jj == (ny-1))&&(ii == (nx-1))){
						printf("%f;\n",long);
					} else {
						printf("%f,",long);
					}
				}
			}
		}')

	
}" |ncgen -o  "${outfile}"

