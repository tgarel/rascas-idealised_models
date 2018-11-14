
import os

################################################################################

halo_ids = ['11518','12763','18546','23233','24695','41361','47123','49444','49905','6114']

path2confFiles = '/scratch/garel/test_rascas_sphinx/00183/'

# Clean PFS files if needed

for j in range(len(halo_ids)):
    # RASCAS 
    rascas_dir = "%s%s%s%s"%(path2confFiles,'halo',halo_ids[j],'/1500A_rf/')
    rascas_cmd = "%s%s%s"%('rm ',rascas_dir,'/00*RASCAS*')
    os.system(rascas_cmd)
    
  

################################################################################

