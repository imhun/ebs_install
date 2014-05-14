PATH=/usr/bin:/etc:/usr/sbin:/usr/ucb:$HOME/bin:/usr/bin/X11:/sbin:.:/usr/vacpp/bin

export PATH

if [ -f "$HOME/.profile" ] 
then
	. ~/.profile
elif [ -f "$HOME/.bash_profile" ]
then
	. ~/.bash_profile
fi
