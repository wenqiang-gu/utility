#!/bin/bash

wcinst-init(){

  # https://cdcvs.fnal.gov/redmine/projects/larwirecell/repository
  larsoft_version=v08_28_01
  larwirecell_version=v08_05_13
  dunetpc_version=v08_27_02
  sl7img=

  # download wcdo.sh
  if ! [ -x "$(command -v wcdo.sh)" ]; then
    echo '[warning] wcdo.sh is not found or executable.' >&2
    echo -e "Would you like to download wcdo.sh now? (y/n)\n"
    read use_wcdo_download
    if [ "$use_wcdo_download" = "y" ];then
      wget https://www.phy.bnl.gov/~wgu/protodune/wcinst/wcdo.sh
      export PATH=$(pwd):$PATH
      chmod +x wcdo.sh
    else
      echo
      echo "Please setup wcdo.sh properly and run this installer again."
      echo
      exit 1
    fi
  fi

  echo
  read -p "Press [Enter] key to continue..."
  
  clear
  echo
  echo "Please verify the software version."
  echo -e "Are they the right versions? (y/n)\n larsoft: $larsoft_version\n larwirecell: $larwirecell_version\n dunetpc: $dunetpc_version\n"
  read larinfo
  echo
  
  if [ "$larinfo" = "n" ];then
    echo "Please specify the desired versions in format (eg, v08_08_00):"
    echo -n "larsoft_version="
    read larsoft_version
    echo -n "larwirecell_version="
    read larwirecell_version
    echo -n "dunetpc_version="
    read dunetpc_version
  fi
  
  echo
  if [ "$sl7img" = "" ];then 
    echo -e "Please choose your source for the sl7 image (1 or 2):\n 1) an existing copy;\n 2) automated download.\n\n"
    read sl7opt
    if [ "$sl7opt" = "1" ];then
      echo
      echo "Please type your path below (eg, path_to_sl7img=../sl7krb.simg):"
      echo "Note: your current working directory is $(pwd)"
      echo
      echo -n "path_to_sl7img="
      read sl7img
      ln -s $sl7img sl7krb.simg
    else
      wcdo.sh get-image sl7krb
    fi
  fi

  # make a local copy of the environment
  rcfile=".wcinst.rc"
  touch $rcfile
  cat <<EOF > "$rcfile"
larsoft_version=${larsoft_version}
larwirecell_version=${larwirecell_version}
dunetpc_version=${dunetpc_version}
EOF

  wcdo.sh init
  wcdo.sh wct
  wcdo.sh make-project myproj sl7krb
  
  # echo
  # echo "Please fill the larsoft version in wcdo-local-myproj.rc as follows (default editor: vim)."
  # echo
  # echo wcdo_mrb_project_name='"'larsoft'"'
  # echo wcdo_mrb_project_version='"'$larsoft_version'"'
  # echo wcdo_mrb_project_quals='"'e17:prof'"'
  # echo
  # read -p "Press [Enter] key to continue..."
  # 
  # vim wcdo-local-myproj.rc
  
  sed -i '/^wcdo_mrb_project_name/ s/.*/wcdo_mrb_project_name="'larsoft'"/g' wcdo-local-myproj.rc
  sed -i '/^wcdo_mrb_project_version/ s/.*/wcdo_mrb_project_version="'$larsoft_version'"/g' wcdo-local-myproj.rc
  sed -i '/^wcdo_mrb_project_quals/ s/.*/wcdo_mrb_project_quals="'e17:prof'"/g' wcdo-local-myproj.rc
  
  echo
  echo "Now the singularity container will start. Wirecell toolkit and LarWirecell package will be installed."
  echo "Once you go into the container, please run: ./wcinst.sh bootstrap"
  echo
  read -p "Press [Enter] key to continue..."

  # go inside the singularity container
  ./wcdo-myproj.sh
}

wcinst-bootstrap(){
 source .wcinst.rc
 source wcdo-myproj.rc
 source wcdo-local-myproj.rc

 source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
 path-prepend $wcdo_ups_products PRODUCTS
 wcdo-mrb-init
 wcdo-mrb-add-source larwirecell $larwirecell_version $larwirecell_version
 wcdo-ups-declare wirecell wctdev
 setup wirecell wctdev -q e17:prof
 wcdo-ups-wct-configure-source
 ./wcb -p --notests install
 setup wirecell wctdev -q e17:prof
 wcdo-wirecell-path default
 echo
 
 # echo "Please change the wirecell version as follows (default editor: vim)."
 # echo "wirecell v0_xx_xx ==> wirecell wctdev"
 # echo
 # read -p "Press [Enter] key to continue..."
 # vim /wcdo/src/mrb/srcs/larwirecell/ups/product_deps
 
 sed -i '/^wirecell/ s/.*/wirecell        wctdev/g' /wcdo/src/mrb/srcs/larwirecell/ups/product_deps 
 
 mrbsetenv
 mrb i
 mrbslp
 echo
 echo "--- test 1: ups active | grep wirecell"
 ups active | grep wirecell
 echo
 echo "--- test 2: ups list -aK+ wirecell | head"
 ups list -aK+ wirecell | head
 echo "Successful installation!"
  
  #echo "Here is an example of wcdo-local-myproj.rc"
  #echo "After you update your wcdo-local-myproj.rc, try ./wcdo-myproj.sh"
  #echo
  read -p "Press [Enter] key to continue..."

  # add environment into wcdo-local-myproj.rc
  rcfile="/wcdo/wcdo-local-myproj.rc"
  touch $rcfile
  cat <<EOF >> "$rcfile"
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunetpc ${dunetpc_version} -q e17:prof

path-prepend \$wcdo_ups_products PRODUCTS
wcdo-mrb-init
wcdo-ups-init
setup wirecell wctdev -q e17:prof
export WIRECELL_PATH=/wcdo/src/wct/cfg:/wcdo/share/wirecell/data
echo WIRECELL_PATH=\$WIRECELL_PATH
mrbsetenv
mrbslp
export FHICL_FILE_PATH=\$WIRECELL_PATH:\$FHICL_FILE_PATH

find-fhicl(){
  fhicl_file=\$1
  for path in \`echo \$FHICL_FILE_PATH  | sed -e 's/:/\n/g'\`;do find \$path -name "\$fhicl_file"  2>/dev/null;done
}
EOF

}

wcinst-help(){
  cat << EOF
  wcinst.sh
    - a help installer for wirecell + singularity
    - based on wcdo.sh (https://github.com/WireCell/wire-cell-singularity)

  usage:
    - show this help message
      - ./wcinst.sh help

    - get wirecell toolkit in three steps
      - ./wcinst.sh init # in host shell
      - ./wcinst.sh bootstrap # in singularity container
      - exit & relogin singularity (./wcdo-myproj.sh)
EOF
}

cmd="${1:-help}"; shift
wcinst-$cmd $@