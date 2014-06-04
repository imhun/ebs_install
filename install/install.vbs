' Include函数，通过FSO组件读取外部函数文件内容
' 通过ExecuteGlobal载入
Sub include(file)
    Dim fso, f, strcon
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f = fso.OpenTextFile(file, 1)
    strcon = f.ReadAll
    f.Close
    ExecuteGlobal strcon
    Set fso=Nothing
    Set f=Nothing
End Sub

Function getResult(fso,logfile)
	getResult="E"
	Set f = fso.OpenTextFile(logfile, 1)
	Do Until f.AtEndOfStream
		strlog=f.ReadLine
		if instr( strlog,"install result : error!")>0 then
			getResult="E"	
		elseif instr( strlog,"install result : success!")>0 then
			getResult="S"	
	  	end if
	Loop
	f.Close
	Set f=Nothing
end function

' 测试
Sub dotest
		'运行参数
		'Set args = WScript.Arguments
		Set fso = CreateObject("Scripting.FileSystemObject")  
	
		'包含文件处理库
		include "..\lib\lib.vbs"
		include "..\lib\lib_install.vbs"
		include "..\lib\aspjson.vbs"
		
    	currDir= GetCurrentFolderFullPath(fso,Wscript.ScriptFullName) 	
    	currPDir=fso.GetParentFolderName(currdir)
    	currDate=CStr(Year(Now()))&Right("0"&Month(Now()),2)&Right("0"&Day(Now()),2)
    	
		srcPath=InputBox("请输入代码目录，默认为当前目录:","请输入代码目录",currdir)	
		if srcPath="" then
			Wscript.quit
		elseif Not fso.FolderExists(srcPath) Then
			MsgBox "目录不存在:<" & histPath & ">"
			wscript.quit
	 	end if
    	
		'获取连接设置,读取json配置文件
		set data=readConfig(fso,"install_conn.cfg")
		set odb=data("db")
		set oahost=data("app")
		set langobj=data("lang")
		
    	dbsid=odb("sid")
    	dbuser=odb("user")
    	dbpw=odb("pwd")
    	cuxpw=odb("cuxpwd")
    	
		hostcount=oahost.count
		
		Set filedata = Collection()
    	filecnt=procFiles(fso,srcPath,currDir)
    	'Wscript.quit
    	appexist=0
    	dbexist=0
    	
		if fso.folderexists(currDir&"\code\app") then
			appexist=1
		end if
		if fso.folderexists(currDir&"\code\db") then
			dbexist=1
		end if
		if appexist=0 and dbexist=0 then
			Msgbox "目录<" & srcPath & ">下不存在有效的代码文件！"
			Wscript.quit
		end if
		
    	rd=getRandom(1,100000)
    	
		logfile="exec.log"
		cmds="%comspec% /k"
		scpcm=currPDir&"\lib\pscp.exe -q -r  -pw [pwd]" 'ssh文件上传，下载命令
		
    	sshcm=currPDir&"\lib\plink.exe -ssh  -pw [pwd] [user]@[host] """ 'ssh命令
    	
		set ws=createobject("wscript.shell")

		renv=". ./setenv.sh;. [profile];" '环境变量
    	
    	sshpre="cd $HOME/[rtdir]; pwd; chmod +x ./*; "&renv&"echo ""NLS_LANG=$NLS_LANG"";"
    	
    	icount=0
    	resultstr="安装结果："
    	For Each row in oahost
    		icount=icount+1
    		set ohost=oahost.item(row)
    		rtype=ohost("type")
    		rhost=ohost.item("host")
    		ruser=ohost.item("user")
    		rpwd=ohost.item("pwd")
    		
	    	instRes=""
    		if rtype="master" or appexist=1 then

	    		sshm=replace(sshcm,"[host]",rhost)
	    		sshm=replace(sshm,"[user]",ruser)
	    		sshm=replace(sshm,"[pwd]",rpwd)
	    		scpm=replace(scpcm,"[pwd]",rpwd)
	    		
	    		prefixhost=replace(rhost,".","_")
	    		rtdir="install_"&currDate&"_"&rd
	    		prompt="==("&rhost&"): "
	    	
			  	'删除下载文件目录	
			  	condir=currDir & "\"&rtDir
			 	if fso.folderexists(condir) then  	
					fso.deletefolder(condir)
				end if
				
				rshtype=getShType(ws,sshm & "echo $0""")
				if rshtype ="ksh" then
			  		rprof="~/.profile"
			    elseif rshtype="bash" then
			    	rprof="~/.bash_profile"
			  	end if
			  	
				sshpre=replace(sshpre,"[profile]",rprof)
				sshpre=replace(sshpre,"[rtdir]",rtdir)
	    		
	    		'删除已有目录，并创建临时目录,上传执行脚本
		    	prm="echo  begin install process: && echo uploading file to server..... "
		    			  
		    	sshupf= sshm&" rm -rf ~/"&rtdir&"; mkdir ~/"&rtdir&";mkdir ~/"&rtdir&"/code;"""&_ 
		    			  " && "&scpm&" "&currPDir&"\lib\common\ "&ruser&"@"&rhost&":"&rtdir &_ 
		    			  " && "& scpm&" "&currPDir&"\lib\install\ "&ruser&"@"&rhost&":"&rtdir
		    			  
	  			if appexist=1 then
	  			  sshupf=sshupf&" && "&scpm&" "&currDir&"\code\app "&ruser&"@"&rhost&":"&rtdir&"/code"
	  			end if
	  			  
		    	if rtype="master" and dbexist=1 then
		    		sshupf=sshupf&" && "&scpm&" "&currDir&"\code\db "&ruser&"@"&rhost&":"&rtdir&"/code"
		    	end if	
		    	
		    	sshupf=prm &" && "&sshupf&" && echo upload file successful ! " 
			
		    	prm=" && echo begin execute install: "
		    	sshinst=sshm&sshpre&"perl install.pl installpath=$HOME/"&rtdir&" cfgfile=$HOME/"&rtdir&"/install.cfg "&_
		  						" appsusr="&dbuser&" appspwd="&dbpw&" dbschemapwd="&cuxpw&" logfile=$HOME/"&rtdir&"/"&prefixhost&"_install.log;"""
		  	    sshinst=prm&" && "&sshinst&" && echo execute install completed " '执行安装
		    		
		        prm=" && echo begin download file from server "
		        sshdwf=		scpm&" "&ruser&"@"&rhost&":"&rtdir&"/"&prefixhost&"_install.log "&currDir&"\"&_ 
		        				" && "&sshm&" rm -rf ~/"&rtdir&";"""
		        sshdwf=prm&" && "&sshdwf&" && echo download file completed  ! " '下载日志文件到本地,删除服务器临时目录
		        
		        'Wscript.echo(sshupf)
		        'Msgbox (sshinst)
		        'Wscript.echo(sshdwf)
		    	spt=cmdproc(sshupf&sshinst&sshdwf,"",1,prompt)
		   
		    	'Wscript.Echo(replace(spt,"&&",vbcrlf))
		    	'Wscript.quit
		    	'ret=ws.run(spt,1,true) '执行下载命令
		    	exec spt
		    	
		    	instres=getResult(fso,currdir&"\"&prefixhost&"_install.log")		
		    else
		    	resultstr=resultstr&chr(10)&"应用节点("&rhost&")无需安装"
	    	end if	    	
    		msgtype=0
	    	if instRes="S" then
    			msgstr="应用节点("&rhost&")安装成功！"
    			resultstr=resultstr&chr(10)&msgstr
    		elseif instRes="E" then
    			msgstr="应用节点("&rhost&")安装失败，详细信息请检查日志文件！"
    			resultstr=resultstr&chr(10)&msgstr
    			if hostcount>icount then
    				msgstr=msgstr&chr(10)&"是否继续安装其余节点?"
    				msgtype=4 
    			end if
    			
    			setnum = MsgBox(msgstr,msgtype)
	  			if setnum=7 then
	  				Exit for
	  			end if
  			end if
  			
  			
    	Next
    	
    	Msgbox(resultstr)
    
        Set fso=Nothing
        
End Sub

' Run
Call dotest()