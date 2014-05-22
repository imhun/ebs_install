Function getObjType(fso,fpath,fname,byref oname,byref olang,byref seq,byref instType,byref objDir)
	sbase = ""
	oname=""
	olang=""
	seq=""
	instType=""
	objDir=""
    sext = Lcase(GetFileExtAndBaseName(fname, sbase)) 
    cnt=0
    
    if instr(fpath,"\ZHS\")>0 then
    	olang="ZHS"
    elseif instr(fpath,"\US\")>0 then
    	olang="US"
    end if
    
	if sext="fmb" then
		otype="FORM"
		oname="CUX." & Ucase(sbase)
		seq=110
		instType="app"
		objDir="forms"
	elseif sext="pll" then
		otype= "RESOURCE"
		oname="CUX." &Ucase(sbase)
		seq=100
		instType="app"
		objDir="resource"
	elseif sext="rdf" then
		otype="REPORT"
		oname="CUX." & Ucase(sbase)
		seq=120
		instType="app"
		objDir="reports"
	elseif sext="rtf" then
		otype="XDO_TEMPLATE"
		oname="CUX." & Ucase(sbase)
		seq=130
		instType="db"
		objDir="xdoload\template"
	elseif sext="class" or sext ="xml" then
		otype="OAF"
		objDir="oaf"
		seq=140
		instType="app"
	elseif sext="pls" or sext="plb" or sext="sql" or sext="ldt" or sext="wft" then
   		Set f = fso.OpenTextFile(fpath, 1,true,0)
		Do Until f.AtEndOfStream
			strline=replace(Ucase(trim(f.ReadLine)),"""","")
			if sext ="sql" or sext="pls" or sext="plb" then		
				if instr(strline,"CREATE TABLE")>0 then
					otype="TABLE"
					stype="CREATE TABLE"	
					seq=10
					instType="db"
					objDir="table"
				elseif instr(strline,"ALTER TABLE")>0 then					
					otype="TABLE_ALTER"
					stype="ALTER TABLE"
					seq=10
					instType="db"
					objDir="table"
				elseif instr(strline,"CREATE GLOBAL TEMPORARY TABLE")>0 then
					otype="TABLE"
					stype="CREATE GLOBAL TEMPORARY TABLE"
					seq=10
					instType="db"
					objDir="table"
				elseif instr(strline,"CREATE OR REPLACE SYNONYM")>0 then
					otype="SYNONYM"
					stype="CREATE OR REPLACE SYNONYM"
					seq=20
					instType="db"
					objDir="synonym"
				elseif instr(strline,"CREATE SEQUENCE")>0 then
					otype="SEQUENCE"
					stype="CREATE SEQUENCE"
					seq=30
					instType="db"
					objDir="sequence"
				elseif instr(strline,"CREATE INDEX")>0 then
					otype="TABLE_INDEX"
					stype="CREATE INDEX"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"INSERT INTO")>0 then
					otype="TABLE_DATA"
					stype="INSERT INTO"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"UPDATE")>0  then					
					otype="TABLE_DATA"
					stype="UPDATE"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"DELETE FROM")>0 then					
					otype="TABLE_DATA"
					stype="DELETE FROM"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"CREATE OR REPLACE PACKAGE BODY")>0 then
					otype="PACKAGE_BODY"
					stype="CREATE OR REPLACE PACKAGE BODY"
					seq=60
					instType="db"
					objDir="package"
				elseif instr(strline,"CREATE OR REPLACE PACKAGE")>0 then
					otype="PACKAGE_SPEC"
					stype="CREATE OR REPLACE PACKAGE"
					seq=40
					instType="db"
					objDir="package"
				elseif instr(strline,"CREATE OR REPLACE VIEW")>0 then
					otype="VIEW"
					stype="CREATE OR REPLACE VIEW"
					seq=50
					instType="db"
					objDir="view"
				elseif instr(strline,"CREATE OR REPLACE FORCE VIEW")>0 then
					otype="VIEW"
					stype="CREATE OR REPLACE FORCE VIEW"	
					seq=50
					instType="db"
					objDir="view"
				elseif instr(strline,"CREATE OR REPLACE TRIGGER")>0 then
					otype="TRIGGER"
					stype="CREATE OR REPLACE TRIGGER"
					seq=70
					instType="db"
					objDir="trigger"
				else
					otype="DB_TEMP"
					seq=75
					instType="db"
					objDir="sql"
				end if
				if otype<>"" and otype<>"DB_TEMP" then
					oarr=split(trim(replace(strline,stype,"")) ," ")
					oname=oarr(0)
					exit do
				end if
			elseif sext="ldt" then
				if olang="" and instr(strline,"LANGUAGE =")> 0 then				
					oa=split(strline," ")
					olang=oa(2)
				elseif otype="" and instr(strline,"DEFINE ")>0 then
					oa=split(strline," ")
					otype=oa(1)
					
					seq=80
					instType="db"
				elseif otype<>"" and instr(strline,"BEGIN "&otype) then
					oa=split(strline," ")
					oname=oa(2)
					if UBound(oa)>=3 then
						oname=oa(3) & "." &oname
					end if 
					if otype="PROGRAM" then
						otype="REQUEST"
					elseif otype="FND_LOOKUP_TYPE" then
						otype="LOOKUP"
					elseif otype="DESC_FLEX" then
						otype="DESCFLEX"
					elseif otype="KEY_FLEX" then
						otype="KEYFLEX"
					elseif otype="REQUEST_GROUP" then
						otype="REQUESTGROUP"
					elseif otype="REQ_SET" then
						otype="REQUESTSET"
					elseif otype="VALUE_SET" then
						otype="VALUESET"
					elseif otype="XDO_DS_DEFINITIONS" then
						otype="XDO_DATADEFINE"
					elseif otype="FND_RESPONSIBILITY" then
						otype="RESPONSIBILITY"
					elseif otype="FND_FORM_CUSTOM_RULES" then
						otype="CUSTOMRULE"
					elseif otype="FND_NEW_MESSAGES" then
						otype="MESSAGE"
					elseif otype="FND_APPLICATION" then
						otype="FND_APP"
					end if
					objDir="fndload\" & lcase(otype)
					exit do
				end if
			elseif sext="wft" then
				if instr(strline,"BEGIN ITEM_TYPE ")>0 then
					oa=split(strline," ")
					otype="WORKFLOW"
					oname="CUX." & oa(2)
					seq=90
					instType="db"
					objDir=lcase(otype)
					exit do
				end if
			end if		
		loop 
		f.close
	end if
	
	
	getObjType=otype
end function

function getObjPos(sfull)
	pos=0
	if instr(sfull,"\package\") >0 then
  		pos= instr(sfull,"\package\")
  	elseif instr(sfull,"\table\") >0 then
  		pos= instr(sfull,"\table\")
  	elseif instr(sfull,"\view\") >0 then
  		pos= instr(sfull,"\view\")
  	elseif instr(sfull,"\synonym\") >0 then
  		pos= instr(sfull,"\synonym\")
  	elseif instr(sfull,"\sequence\") >0 then
  		pos= instr(sfull,"\sequence\")
  	elseif instr(sfull,"\trigger\") >0 then
  		pos= instr(sfull,"\trigger\")
  	elseif instr(sfull,"\sql\") >0 then
  		pos= instr(sfull,"\sql\")
  	elseif instr(sfull,"\mv\") >0 then
  		pos= instr(sfull,"\mv\")
  	elseif instr(sfull,"\fndload\") >0 then
  		pos= instr(sfull,"\fndload\")
  	elseif instr(sfull,"\forms\") >0 then
  		pos= instr(sfull,"\forms\")
  	elseif instr(sfull,"\resource\") >0 then
  		pos= instr(sfull,"\resource\")
  	elseif instr(sfull,"\reports\") >0 then
  		pos= instr(sfull,"\reports\")
  	elseif instr(sfull,"\oaf\") >0 then
  		pos= instr(sfull,"\oaf\")
  	elseif instr(sfull,"\workflow\") >0 then
  		pos= instr(sfull,"\workflow\")
  	elseif instr(sfull,"\xdoload\") >0 then
  		pos= instr(sfull,"\xdoload\")
  	elseif instr(sfull,"\data\") >0 then
  		pos= instr(sfull,"\data\")
  	end if
  	
  	getObjPos=pos
end function
