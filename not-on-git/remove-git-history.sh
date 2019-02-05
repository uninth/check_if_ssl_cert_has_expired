#!/bin/sh

case $1 in
	"doit")	set -x
	;;
	*)	echo read the source, luke
		exit
	;;
esac

CONFIG=/tmp/config.$$
cp .git/config $CONFIG

rm -fr .git && mkdir -p .git/info
cat <<-EOF > .git/info/attributes
# see man gitattributes
*.sh ident
*.pl ident
*.c ident
*.md ident
EOF
cp $CONFIG .git/config
echo ".git removed, new .git/info created"
echo "existing .git/config preserved"
echo "remove .git/config if needed"

cat << EOF

If you just want to remove the git history for an existing project
do this:

mv .git/config /tmp/

export GITURL=`sed '/url/!d; s/.*=//; s/[ \t]*//' $CONFIG`
echo url in config: $GITURL

git init;

git remote add origin $GITURL

git add .; git commit -m "Initial commit"; git push origin master

git push --force origin master

A set of initial commands are here:

rm -fr .git; git init; git add .; git commit -m 'initial commit'; git tag 1.0-1

EOF

echo moving $0 to not-on-git

if [ ! -d not-on-git ]; then
	mkdir not-on-git
fi

mv $0 not-on-git

