# Pkg-tracker

This simple bash script will :
- download EPEL sqlite metadata for the dist defined in the script (6 and 7)
- verify which version from epel you built (through pkg.list) and submit scratch build in cbs
- send a mail with the cbs taskID and also how to rebuild it again without --scratch

You need to define your pkg.list like this (as an example, as then the script will also modify the NEVR when submitting a new build job :
```
# List of pkgs we care about
# headers: $dist | $name | $cur_ver
7|nginx|1.10.1-1.el7
6|nginx|1.10.1-1.el6

```
