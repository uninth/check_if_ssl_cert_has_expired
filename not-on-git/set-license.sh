#!/bin/bash

export YYYY=`date +%Y`
export YOUR_FULL_NAME="Niels Thomas Haugård"
export ORGANISATION="haugaard.net inc"

function choice_of()
{
        tput clear
        echo
        echo "Choose a license "
        tput cols | awk '{ while ( $1 -- > 0) printf("-") }'
        select CHOICE
        do
                break
        done
}

LIC_FILES="LICENSE.apache2 LICENSE.checkpoint LICENSE.gnu.v3 LICENSE.bsd3"
LIC_FILES="LICENSE.*"

choice_of $LIC_FILES
case ${CHOICE} in
	"")	MY_LICENSE=LICENSE.bsd3
	;;
	*)	MY_LICENSE=${CHOICE}
	;;
esac

# gsed add s/.\{80\} /&\n/g
sed "
	s/_YYYY_/${YYYY}/g;
	s/_YOUR_FULL_NAME_/${YOUR_FULL_NAME}/g;
	s/_ORGANISATION_/${ORGANISATION}/g
	" ${MY_LICENSE} > LICENSE

echo License set to $MY_LICENSE

echo moving LICENSE.* and $0 to not-on-git

if [ ! -d not-on-git ]; then
	mkdir not-on-git
fi
mv LICENSE.* not-on-git
mv $0 not-on-git

