#!/bin/bash
dist_releases="6 7"
pkg_list_file="pkg.list"
srpm_tree="/home/arrfab/rpmbuild/Downloads"
logfile="/home/arrfab/pkg-tracker.log"
mail_rcpt="fabian.arrotin@arrfab.net"

# Downloading needed metadata sqlite files
for rel in ${dist_releases} ; do
  if [ "$rel" = "7" ] ;then
    file_ext="xz"
  else
    file_ext="bz2"
  fi
 sqlite_db=$(curl --silent https://dl.fedoraproject.org/pub/epel/${rel}/x86_64/repodata/repomd.xml|grep primary.sqlite|cut -f 2 -d '"')
  curl --silent https://dl.fedoraproject.org/pub/epel/${rel}/x86_64/${sqlite_db} > epel-${rel}.sqlite.${file_ext}
  if [ "$rel" = "7" ] ;then
    /bin/rm epel-${rel}.sqlite
    unxz epel-${rel}.sqlite.${file_ext}
  else
    /bin/rm epel-${rel}.sqlite
    bunzip2 epel-${rel}.sqlite.${file_ext}
  fi
done

grep -v '^#' $pkg_list_file| while read line ; do
  dist=$(echo $line|cut -f 1 -d '|') 
  pkg_name=$(echo $line|cut -f 2 -d '|')
  cur_ver=$(echo $line|cut -f 3 -d '|')
  epel_ver=$(echo "select version,release from packages where name='$pkg_name';" |sqlite3 -separator '-' epel-${dist}.sqlite| head -n 1)    
  epel_ver_dl=$(echo "select version,release from packages where name='$pkg_name';" |sqlite3 -separator '-' epel-${dist}.sqlite |head -n 1)    
  if [ "$cur_ver" != "$epel_ver" ] ;then
    echo "We need to download $pkg_name-$epel_ver_dl as we have only $cur_ver"
    if [ "$dist" = "7" ] ; then
      curl --silent https://dl.fedoraproject.org/pub/epel/${dist}/SRPMS/${pkg_name:0:1}/${pkg_name}-${epel_ver_dl}.src.rpm >  $srpm_tree/${pkg_name}-${epel_ver_dl}.src.rpm
    else
      curl --silent https://dl.fedoraproject.org/pub/epel/${dist}/SRPMS/${pkg_name}-${epel_ver_dl}.src.rpm >  $srpm_tree/${pkg_name}-${epel_ver_dl}.src.rpm      
    fi
    # Now submitting the job in cbs
    cbs_task_info=$(cbs build --scratch --nowait --noprogress infrastructure${dist}-el${dist} $srpm_tree/${pkg_name}-${epel_ver_dl}.src.rpm|grep Task)
    echo "[+] $(date +%Y%m%d) - Submitted ${pkg_name}-${epel_ver_dl}.src.rpm : ${cbs_task_info}" >> $logfile
    echo -e "Submitted ${pkg_name}-${epel_ver_dl}.src.rpm : ${cbs_task_info} \n To rebuild with scratch, run : \n cbs build infrastructure${dist}-el${dist} $srpm_tree/${pkg_name}-${epel_ver_dl}.src.rpm"| mail -r ${mail_rcpt} -s "[Infra] new pkg submit : ${pkg_name}-${epel_ver_dl}.src.rpm" ${mail_rcpt}
    # Updating now pkg.list
    sed -i "s/${dist}|${pkg_name}|.*/${dist}|${pkg_name}|${epel_ver_dl}/g" pkg.list ${pkg_list_file}
  fi


done
