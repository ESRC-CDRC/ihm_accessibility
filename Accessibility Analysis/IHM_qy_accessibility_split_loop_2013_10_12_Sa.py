#!/usr/bin/jython
from org.opentripplanner.scripting.api import OtpsEntryPoint
import time


#%%

# jython -Dpython.path=otp-1.2.0-shaded.jar IHM_qy_accessibility_split_loop.py
# jython -Dpython.path=otp-x.y.z-shaded.jar myscript.py
#  java -cp otp-1.2.0-shaded.jar:jython-standalone-2.7.0.jar org.opentripplanner.standalone.OTPMain --script IHM_qy_accessibility_split_loop.py


print('Instantiate an OtpsEntryPoint')

dir_graph = 'graphs'
otp = OtpsEntryPoint.fromArgs(['--graphs', dir_graph,
                               '--router', 'gb'])

indir = 'OD_lists'
flo = '_OA2013_origs.csv'
facility = '_dests'
#mins = ['00','10','05']
#mins = ['20','15','25']
#mins = ['30','45','35']
#mins = ['40','50','55']

mins = ['00','30']
hours = ['08','10','12','14','16','18','20','22','09','11','13','15','17','19','21','07','23','00','06','05','04','03','02','01']

#%%
print('Get the default router')
router = otp.getRouter('gb')

#%%
print('Create a default request for a given departure time')

for h in hours:
	for m in mins:
		datetime = ['2013', '10', '12', h, m, '00']
		fl_out = '../results/IHM_wp5_oa'+facility+datetime[0][2:]+datetime[1]+datetime[2]+'_'+datetime[3]+datetime[4]+'.csv'
		print('>>>>> '+fl_out+' ---------------------------------')

		req = otp.createRequest()
		datetime2 = [int(x) for x in datetime]
		req.setDateTime(datetime2[0],datetime2[1],datetime2[2],datetime2[3],datetime2[4],datetime2[5])  # set departure time
		req.setMaxTimeSec(7200)                   # set a limit to maximum travel time (seconds)
		req.setModes('WALK,TRANSIT')             # define transport mode
	#req.setSearchRadiusM(500)                 # set max snapping distance to connect trip origin to street network
	# req.setMaxWalkDistance = 0.5                 # set maximum walking distance ( kilometers ?)
	# req.walkSpeed = walkSpeed                 # set average walking speed ( meters ?)
	# req.bikeSpeed = bikeSpeed                 # set average cycling speed (miles per hour ?)

	# Read Points of Destination - The file points.csv contains the columns GEOID, X and Y.

		origs = otp.loadCSVPopulation(indir+'/'+flo, 'oa_lat', 'oa_lon')
		print('origs read!')


	# Create a CSV output
		print('create output file')
		with open(fl_out,'a') as fo:
			fo.write(','.join([ 'origin', 'destination', 'type', 'walk_distance', 'travel_time', 'boardings', '\n' ]))

	# run OTP 
		print('generate distances')
		j = -1
		with open(fl_out,'a') as fo:
			for o in origs:
	
			  j = j+1
			  if j % 500 == 0: print(str(j)+' stops processed '+time.strftime('%a %H:%M:%S'))
			  req.setOrigin(o)
			  spt = router.plan(req)
			  if spt is None: continue
	
			  # Evaluate the SPT for all points
			  dests = otp.loadCSVPopulation(indir+'/OA2013_'+o.getStringData('oa11cd')+facility+'.csv', 'am_lat', 'am_lon')
			  #print('dests read!')
			  result = spt.eval(dests)
	  
			# Add a new row of result in the CSV output
			  for r in result:
				row = [o.getStringData('oa11cd'), r.getIndividual().getStringData('amenity'), r.getIndividual().getStringData('type'), r.getWalkDistance() , r.getTime(),  r.getBoardings(), '\n' ]
				fo.write(','.join(str(x) for x in row))

	fo.close()
