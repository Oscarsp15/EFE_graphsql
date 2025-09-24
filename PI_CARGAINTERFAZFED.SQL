CREATE OR REPLACE PROCEDURE PI_CARGAINTERFAZFED(DATE, DATE, CHARACTER VARYING(5), CHARACTER VARYING(30)) RETURNS INTEGER LANGUAGE NZPLSQL AS BEGIN_PROC
DECLARE
	
	P_FecCorte 			ALIAS FOR $1;
	P_FecCorteRCC 		ALIAS FOR $2;
	P_FlgSistemaDestino ALIAS FOR $3;
	P_FlgEjecucion		ALIAS FOR $4;
	
	--- Variables del proceso
	V_FecCorte			Date;
	V_CodFecCorte		Int;
	
	V_FecCorteRCC		Date;
	V_CodFecCorteRCC	Int;
	
	V_FecCorteUlt		Date;
	V_Periodo			Int;
	V_FecCorteEQ        date;
	
	--- Variables de ejecuci n
	V_FlgEjecucion		varchar(30)	;
	V_NroRegistros		int = 0		;		-- Contiene el numero de registros procesados en cada paso.
	V_CodPaso			smallint	;		-- Contiene el codigo (numero) de paso.
	V_CodInicioProceso	varchar(20);		-- Se carga al registrar el inicio ejecucion del proceso.
	V_NroEjecucion		int			;		-- Carga el Numero de Ejecucion(de la variable V_CodInicioProceso).
	V_CodProceso		smallint	;		-- Carga el Codigo del proceso (de la variable V_CodInicioProceso).
	V_CodError			int = 0		;		-- Carga el Codigo de error en la ejecucion.
	V_ret				int			;		-- Carga el valor recibido de la ejecicion de algun proceso. 
	V_NroAprobados		int = 0;

	--- Otras variables
	v_Enter					varchar(50)	 := CHR(13) || CHR(10);
	v_linea_simple			varchar(200) := REPEAT('-',95);
	v_linea_doble			varchar(200) := REPEAT('=',95);
	v_7Espacios				varchar(200) := REPEAT(' ',7);
	v_titulo				varchar(200) := 'MATRIZ FED (BIG TABLE)';
	v_destino				varchar(2000):= 'wclaudio@efectiva.com.pe';
	v_CadMsgTxt01			varchar(20000);	

	V_BK_E					integer;
	V_BK_M					integer;
	V_BK_F					integer;
	V_BK_A					integer;
	V_BK_H					integer;

	V_RE_E					integer;
	V_RE_M					integer;
	V_RE_F					integer;
	V_RE_A					integer;
	V_RE_H					integer;
	V_Inicio				timestamp;

--	v_servidor				varchar(20);
--	v_carpeta				varchar(200);
--	v_archivo				varchar(200);
	v_ejecucion				BigInt;
	V_FlgAmbiente      		ByteInt;		-- 0 Produccion.
	V_ejecutaLog			byteint = 1;	--   0->No ejecuta LOG, 	1->Si ejecuta LOG
	V_Mensaje				varchar(100);
	V_Version				SmallInt;

	BEGIN
		/*
		--- Cambios
		
			$* y marca baja.
				Solicitado	:	Por Lucia

			#03WCA
				Fecha		:	29.Nov.2019
				Motivo		:	Incluir rechazo 95 Saldo Vencido UM.
				Solicitado	:	Por Adenovich (S. 23135)				
				
			#E2E04
				Fecha		:	31.Ene.2021
				Motivo		:	Proyecto Motor Big Table
				Solicitado	:	Proyecto Motor.				
				
			#E2E05
				Fecha		:	24.Abr.2021
				Motivo		:	Incluir rechazo Score Equifax RP3
				Solicitado	:	Proyecto Motor.

			#WCA05
				Fecha		:	20.Sep.2021
				Motivo		:	Ajustes Motor
				Solicitado	:	Proyecto Motor.

			#WCA06
				Fecha		:	20.Sep.2021
				Motivo		:	Correccion de orden en archivo TXT
				Solicitado	:	Proyecto Motor.

			#WCA07
				Fecha		:	20.Oct.2021
				Motivo		:	Considerar a efectinegocio en Segmentos
				Solicitado	:	Proyecto Motor.

			#WCA08
				Fecha		:	21.Oct.2021
				Motivo		:	Correccion del reperfilamiento, todo lo debe traer desde el modelo.
								y los grupos considerar las bases de bala de plata y sustento
				Solicitado	:	Proyecto Motor.

			#WCA09
				Fecha		:	27.Oct.2021
				Motivo		:	Correccion al formar el Grupo G8 y G9
				Solicitado	:	Proyecto Motor.

			#WCA10				
				Fecha		:	10.Nov.2021
				Motivo		:	S.26648-CAMBIO DE REGLA BIG TABLE A PRODUCTO CONVENIO
				Solicitado	:	Riesgos - Gonzalo Leon.

			#WCA11				
				Fecha		:	11.Nov.2021
				Motivo		:	S.26697-AJUSTE A PROCESOS BIG TABLE PARA INCORPORAR CLIENTES NBK EN BLACKLIST
				Solicitado	:	Riesgos - Gonzalo Leon.

			#WCA12
				Fecha		:	21.Dic.2021
				Motivo		:	S.XXXX-CONSIDERAR MODELO EN TODOS LOS NEGOCIOS
				Solicitado	:	Riesgos - Gonzalo Leon.

			#WCA13
				Fecha		:	24.Mar.2022
				Motivo		:	S.27319 - AJUSTES BATCH EN ETIQUETAS DE BIG TABLE
								- Cambiar la etiqueta de los ObsRech18 (RP3 Calificacion y/o score malos) por obsrech20
				Solicitado	:	Riesgos - Gonzalo Leon.

			#WCA14
				Fecha		:	25.May.2022
				Motivo		:	S.27449-AJUSTES DE PERFILES ELECTRO Y EFECTIVO (LIMA NORTE)
				
			#E2E15
				Fecha		:	01.Ago.2022
				Motivo		:	S.27431- CORREGIR FILTROS EN HIPOTECARIO

			#E2E16
				Fecha		:	29.Sep.2022
				Motivo		:	S.XXXXX- LEER VISTA DE REGLAS DURAS SOLO UNA VEZ				
				
			#E2E17
				Fecha		:	22.Nov.2022
				Motivo		:	S.28153- Alineamiento de Reglas Comerciales
								- Desactivar a todos los negocios MicroZonaPeligrosa: obsRech14
			
			#E2E18
				Fecha		:	30.Nov.2022
				Motivo		:	S.26481- Agregar base TC				
				
			#E2E19
				Fecha		:	14.Jul.2023
				Motivo		:	S.29033- Carreteras EfectiNegocios
								S.29490- Ajuste de Carreteras EfectiNegocios (Batch)				
		
			#E2E20
				Fecha		:	23.Ago.2023
				Motivo		:	S.29439-AJUSTE REGLA DE REPROGRAMADOS 
								S.29279-ACTUALIZAR ETIQUETA REGLA DE EDAD MINIMA PERMITIDA (BATCH)		
			
			#E2E21
				Fecha		:	21.Sep.2023
				Motivo		:	S.29736-AJUSTE DE ZONAS EN CARRETERAS EFECTINEGOCIOS
								S.29746-RESCATE REPROGRAMADOS																												
				
			#@E2E22 		
				Fecha		:	26.Sep.2023
				Motivo		:	S.29745 - Clientes Impulso SSFF (limpiar leads impulso de BBMM)	
			
			#@E2E23 		
				Fecha		:	11.Oct.2023
				Motivo		:	S.29735 - Control de apetito en Efectivo
			
			#@E2E24	
				Fecha		:	21.Nov.2023
				Motivo		:	S.29998 - Control de apetito en Efectivo - Fase 2			
			
			#@COSR25 		
				Fecha		:	24.Nov.2023
				Motivo		:	29565- S.WOCCU - EVALUACION DE EXTRANJEROS
			
			#@MLA26	
				Fecha		:	20.Feb.2024
				Motivo		:	S.30397 - Medida Apetito III Efectivo			
			
			#@MLA27	
				Fecha		:	08.Ago.2024
				Motivo		:	S.31336 - Versionamiento BATCH-ONLINE

			#@CSR28
				Fecha		:	19.Feb.2025
				Motivo		:	S.31996-CONTROL PARA DESFASE DE CALIFICACION EN REPORTES RCC
				
			#@MLA29
				Fecha		:	20.Feb.2025
				Motivo		:	S.32041 -Ajuste de Exceso de Entidades		

			#@E2E28	
				Fecha		:	25.Mar.2025
				Motivo		:	S.31956 - Carreteras Efectivo			
				
			#@MLA29	
				Fecha		:	20.Ago.2025
				Motivo		:	S.32808- Optimizacion OB3

			#@E2E29	
				Fecha		:	02.setiembre.2025
				Motivo		:	S.33175- Ajustes de reglas bigtable para efectinegocio
					
*/
		---
		V_Version	= 25; --24
		V_Inicio	= now();

		---
--		v_servidor	= '10.142.15.218';
--		v_carpeta	= '/nzscratch/nz/buffer/SalidaBD';
--		v_archivo	= 'FF_INTERFAZFED.txt';
		--- Parametros pasados a variables
		V_FecCorte			= P_FecCorte;
		V_CodFecCorte		= To_Char(P_FecCorte,'YYYYMM');
		V_FecCorteRCC		= P_FecCorteRCC;
		V_CodFecCorteRCC	= To_Char(P_FecCorteRCC,'YYYYMM');
		V_FecCorteUlt		= Add_months(Last_Day(P_FecCorteRCC),2); 
		V_Periodo			= TO_CHAR(ADD_MONTHS(P_FecCorteRCC,2),'YYYYMM');			
		if isnull(P_FlgEjecucion, '') = '' then
			V_FlgEjecucion  := 'SSSSSSSSSSSSSSSS';
		else
			V_FlgEjecucion	:= P_FlgEjecucion;
		end if;
	
		--  Registra inicio de ejecucion.
		If V_ejecutaLog = 1 Then	
			begin autocommit on
				set catalog PROD_PROCESOS;
				V_CodInicioProceso	:= PROD_PROCESOS.DBO.PI_ExecProcesoInicio('PI_CARGAINTERFAZFED',V_FecCorte,V_FecCorteRCC,'','','');
				V_CodProceso		:= PROD_PROCESOS.DBO.f_left_udf(V_CodInicioProceso,5) ;
				V_NroEjecucion		:= PROD_PROCESOS.DBO.f_right_udf (V_CodInicioProceso,10) ;
				set catalog PROD_MODELOS;
			end;
		end if;		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 1. Procesamiento de las aprobaciones de Bases Masivas
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 1;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
		begin
			-- #WCA16
			Drop Table DBO.TmpV_ReglasDuras_ if exists;
			CREATE TEMP TABLE DBO.TmpV_ReglasDuras_ AS
			select a.*,
			case when nvl(a.edad,0)<21 or (nvl(a.edad,0)=74 and nvl(a.edadmeses,0)>10) or nvl(a.edad,0)>74 Then 'S' else 'N' end as FlgRechazoEdad, --#@E2E29
			case when isnull(a.DEUDAACTUALEFE,-1)>0 then 'S' else 'N' end as FlgDeudaActualEFE --#@E2E29
			from PROD_MODELOS.DBO.V_REGLASDURAS a
			where a.FecCorte = V_FecCorte and a.FecCorteRCC = V_FecCorteRCC
			DISTRIBUTE ON (NroOrden)
			; -- #WCA16
		
			-- 
			DROP TABLE DBO.TMP_DETALLEBASEMASIVAS IF EXISTS;
			CREATE Temp table DBO.TMP_DETALLEBASEMASIVAS AS
			SELECT	NROORDEN, KEYBD, MAX(BDVALUE) FLBAPROB
			FROM		PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS 		--#WCA05
			WHERE 		PERIODO = V_Periodo and TipoAmbiente=1
			GROUP BY	NROORDEN, KEYBD;


			DROP TABLE DBO.TMP_DETALLEBASEMASIVASPROCESOEFECTIVO IF EXISTS; --#@E2E28 Inicio
			CREATE Temp table DBO.TMP_DETALLEBASEMASIVASPROCESOEFECTIVO AS
			SELECT a.NROORDEN,
			CASE when b.flgbdPL='S' THEN PRIORIDADPL ELSE 99999999 END BASEPRIORIDAD,			
			ROW_NUMBER() OVER (PARTITION BY NROORDEN ORDER BY BASEPRIORIDAD ASC) PrelacionTipoProceso,			
				CODTIPOPROCESO,CODTIPOSUBPROCESO
			FROM PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS a
			Left join Prod_Modelos.DBO.UMD_FED_BASESMASIVASBI b on a.Keybd = b.Keybd
			WHERE PERIODO = V_Periodo and TipoAmbiente=1 AND CATEGORIA = 'EFECTIVO' AND BDVALUE = 'S' AND FecCorte <= V_FecCorte; --#@E2E28 Final

			 
			DROP TABLE DBO.TMP_DETALLEBASEMASIVASAPROB IF EXISTS;
			CREATE Temp table DBO.TMP_DETALLEBASEMASIVASAPROB
			AS
			SELECT		NROORDEN,				
            	--#@E2E04 Inicio					
            	--KEYBD
				-- Reenganche,Rec. Crediefectivo, TDP, Dormidos, Retanqueo,Rec.
         			MAX(CASE WHEN KEYBD IN ('117','108','215','111','107','216','110','115') 	AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END) 	as APRRECEFECTIVA	,	-- G0
				  --MAX(CASE WHEN KEYBD IN ('100', '101')                                      	AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END) 	as APRBKEFECTIVA	,	-- G1
					MAX(CASE WHEN KEYBD IN ('100', '101','223','224')                           AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END) 	as APRBKEFECTIVA	,	-- G1 #WCA08
					MAX (CASE WHEN KEYBD IN ('219')												AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END)	AS APRNBKEFECTIVA	,	-- G10
					MAX (CASE WHEN KEYBD IN ('203','204','205','206','207')						AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END)	AS APRRECSUSTENTO	,	-- G8
				  --MAX (CASE WHEN KEYBD IN ('220','221')										AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END)	AS APRBKSUSTENTO		-- G9
					MAX (CASE WHEN KEYBD IN ('220','221','225')									AND FLBAPROB = 'S' THEN 'S' ELSE 'N' END)	AS APRBKSUSTENTO		-- G9 #WCA08
				--#@E2E04 Final
			
			FROM		DBO.TMP_DETALLEBASEMASIVAS
			GROUP BY	NROORDEN;			
			
			
			--#E2E18
			drop table DBO.TMP_DetalleBaseMasivaTC if exists;
			CREATE Temp table DBO.TMP_DetalleBaseMasivaTC
			as 
			select
			a.nroorden, 
			MAX(CASE WHEN a.KEYBD IN ('229','228') AND a.FLBAPROB = 'S' and b.flgtipoclienteefe ='REC' THEN 'S' ELSE 'N' END) 	as APRRECTC	,	-- G0 
			MAX(CASE WHEN a.KEYBD IN ('229','228') AND a.FLBAPROB = 'S' and b.flgtipoclienteefe ='BK'  THEN 'S' ELSE 'N' END) 	as APRBKTC		-- G1 #WCA08
			
			FROM DBO.TMP_DETALLEBASEMASIVAS a
			left join DBO.TmpV_ReglasDuras_ b
			on a.nroorden = b.nroorden
			GROUP BY	a.NROORDEN;
		 
			--#E2E18
			drop table DBO.tmp_GrupoB if exists;
			CREATE Temp table DBO.tmp_GrupoB
			as 
			select
			distinct nroorden from PROD_ANALITICA.DBO.V_DATOSCONVENIOS	
			where CODFECCORTE=V_CodFecCorte and 	CODGRUPO='B' and FLGTIPOEMPRESA='I'  ;
			 
			-- REPERFILAMIENTO
			--
			
			--Efectivo Recurrentes 
			Drop Table DBO.TmpPerfilEfectivorecurrente If Exists;  
			CREATE Temp table DBO.TmpPerfilEfectivorecurrente
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento,Cod_Indicador
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento,Cod_Indicador,
						row_number() over (partition by nroorden order by FecCorte Desc) as Id
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1
						  and keybd in (107,108,110,111,112,113,114,115,116,117,203,204,205,206,207,215,216,222)					
				)a
			where a.id =1;
			 
			--Efectivo Bancarizados
			Drop Table DBO.TmpPerfilEfectivobancarizado If Exists;
			CREATE Temp table DBO.TmpPerfilEfectivobancarizado
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento,
						row_number() over (partition by nroorden order by FecCorte Desc) as Id
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS --#WCA05
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd in (100,101,220,221,223,224,225) 					
				)a
			where a.id =1;
		 
			--Electro Recurrentes
			Drop Table DBO.TmpPerfilElectrorecurrente If Exists;
			CREATE Temp table DBO.TmpPerfilElectrorecurrente
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento,
						row_number() over (partition by nroorden order by FecCorte Desc) as Id
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd in (126,127,128,130,131,208,209,210,211,212,217)				
				)a
			where a.id =1; 
		 
			--Electro Bancarizados
			Drop Table  DBO.TmpPerfilElectrobancarizado If Exists;
			CREATE Temp table DBO.TmpPerfilElectrobancarizado
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento,
						row_number() over (partition by nroorden order by FecCorte Desc) as Id
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd in (123,124,213)					
				)a
			where a.id =1;
			-- Demora 2 seg - (17569448 rows affected)

			--Motos Recurrentes
			Drop Table DBO.TmpPerfilMotosrecurrente If Exists;
			CREATE Temp table DBO.TmpPerfilMotosrecurrente
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento,
						row_number() over (partition by nroorden order by FecCorte Desc) as Id
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd in (120,122,140,141)				
				)a
			where a.id =1;
		 
			--Motos Bancarizado
			Drop Table DBO.TmpPerfilMotosbancarizado If Exists;
			CREATE Temp table DBO.TmpPerfilMotosbancarizado
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento,
						row_number() over (partition by nroorden order by FecCorte Desc) as Id
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd in (119,121,138,139)					
				)a
			where a.id =1;
			 

			--EfectiNegocio
			Drop table DBO.TmpPerfilEfectiNegocio if exists;
			CREATE Temp table DBO.TmpPerfilEfectiNegocio
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.CODSEGMICROPEQUENACOMERCIAL as Reperfilamiento,bdvalue,
			case when bdvalue='S' then a.CODTIPOPROCESO else 5 end TipoProceso__,
			DECODE(TipoProceso__,0,3,TipoProceso__) TipoProceso_, 
			DECODE (TipoProceso_,5,3,TipoProceso_) TipoProceso,
			a.marca
			
			from
				(
				--	select 
				--		nroorden,FecCorte,keybd,Reperfilamiento,CODSEGMICROPEQUENACOMERCIAL,
				--		CODTIPOPROCESO,bdvalue,marca,
				--		row_number() over (partition by nroorden order by FecCorte Desc) as Id
				--	from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05
				--	where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd = 102	
				
				select 
					a.nroorden,a.FecCorte,nvl(b.keybd,102) keybd,a.BKMICRO as Reperfilamiento,a.CODSEGMICROPEQUENACOMERCIAL,
					nvl(b.CODTIPOPROCESO,3) CODTIPOPROCESO , nvl(b.bdvalue,'N') bdvalue,
			--		case when nvl(a.CREDITONUMCUOTASPAGADAS,0)>=4 then 'REC' else 'BK' end marca,
					case when nvl(a.CODTIPOCLIENTE,0)=2 then 'REC' else 'BK' end marca,
					row_number() over (partition by a.nroorden order by a.FecCorte Desc) as Id				
			--	from PROD_MODELOS.dbo.BASESMICROPEQUENAEMPRESA a
				from PROD_MODELOS.dbo.UMD_FED_UNIVERSOBMMICROPEQUENAEMPRESA a
				left join PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS b
				 on b.KEYBD=102 and TipoAmbiente=1 and PERIODO= V_Periodo and a.NROORDEN=b.nroorden and a.FECCORTE=b.feccorte
				WHERE a.FECCORTE>V_FecCorteRCC AND a.FecCorte <= V_FecCorteUlt				
				)a
			where a.id =1;
		
			--Tarjeta Credito			
			Drop table DBO.TmpPerfilTarjetaCredito if exists;
			CREATE Temp table DBO.TmpPerfilTarjetaCredito
			as
			select a.NROORDEN, a.FecCorte, a.keybd, a.Reperfilamiento
			from
				(
					select 
						nroorden,FecCorte,keybd,Reperfilamiento 
					from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	--#WCA05 -- Solamente existe para TC (228, 229)
					where FecCorte <= V_FecCorteUlt and PERIODO= V_Periodo and TipoAmbiente=1 and keybd in(228,229)					
				)a;			
	 		
			--#@E2E04 Inicio
			
			Drop table DBO.Reperfilado if exists;
			CREATE Temp table DBO.Reperfilado
			as
			select a.NroOrden,a.FecCorte,h.TipoProceso,h.marca,b.Cod_Indicador,
				b.FecCorte as RecEfectivoFecCorte, 	b.keybd as RecEfectivoKeyBd,
				c.FecCorte as BkEfectivoFecCorte , 	c.keybd as BkEfectivoKeyBd,
				d.FecCorte as RecElectroFecCorte , 	d.keybd as RecElectroKeyBd,
				e.FecCorte as BkElectroFecCorte  , 	e.keybd as BkElectroKeyBd,
				f.FecCorte as RecMotosFecCorte   , 	f.keybd as RecMotosKeyBd,
				g.FecCorte as BkMotosFecCorte    ,	g.keybd as BkMotosKeyBd,
				h.FecCorte as BkMicroFecCorte	 ,	h.keybd as BkMicroKeyBd,	
				i.FecCorte as BkTDCFecCorte	 	 ,	i.keybd as BkTDCKeyBd,	--#E2E18				
				
				/*
				max(Case when b.reperfilamiento is null  	then a.RECEFECTIVO	else cast(b.reperfilamiento as byteint) end) as RecEfectivo,
				max(Case when c.reperfilamiento is null  	then a.bkefectivo  	else c.reperfilamiento 					end) as BkEfectivo,
				max(Case when d.reperfilamiento is null  	then a.recElectro  	else cast(d.reperfilamiento as byteint) end) as RecElectro,
				max(Case when e.reperfilamiento is null  	then a.bkelectro 	else e.reperfilamiento 					end) as BkElectro,
				max(Case when f.reperfilamiento is null		then a.RECMOTOS		else cast(f.reperfilamiento as byteint) end) as RecMotos,
				max(Case when g.reperfilamiento is null  	then a.bkmotos  	else g.reperfilamiento 					end) as Bkmotos,			
				max(Case when h.reperfilamiento	is null  	then ''  			else h.reperfilamiento  				end) as BkMicro
				*/
				max(a.RECEFECTIVO				) as RecEfectivo,   --#WCA08
				max(a.bkefectivo 				) as BkEfectivo,    --#WCA08
				max(a.recElectro 				) as RecElectro,    --#WCA08
				max(a.bkelectro 				) as BkElectro,     --#WCA08
				max(a.RECMOTOS					) as RecMotos,      --#WCA08
				max(a.bkmotos  					) as Bkmotos,		--#WCA08
			--	max(nvl(h.reperfilamiento,'')  	) as BkMicro   , 	--#WCA08
				max(nvl(h.reperfilamiento,'RECH')  	) as BkMicro, 	--#WCA08				
				max(case when a.FLGTIPOCLIENTEEFE ='BK' then nvl(i.reperfilamiento,'') else '' end	) as BKTDC,		--#E2E18
				max(case when a.FLGTIPOCLIENTEEFE ='REC' then nvl(i.reperfilamiento,'') else '' end	) as RECTDC	--#E2E18
				

			--From PROD_MODELOS.DBO.V_REGLASDURAS 		a	--#WCA05
			From DBO.TmpV_ReglasDuras_					a	--#WCA16
			Left join DBO.TmpPerfilEfectivorecurrente 	b 					 
				on a.NROORDEN=b.NroOrden
			Left join DBO.TmpPerfilEfectivobancarizado  c 					 
				on a.NROORDEN=c.NroOrden
			Left join DBO.TmpPerfilElectrorecurrente	d 					 
				on a.NROORDEN=d.NroOrden
			Left join DBO.TmpPerfilElectrobancarizado	e 					 
				on a.NROORDEN=e.NroOrden
			Left join DBO.TmpPerfilMotosrecurrente		f 					 
				on a.NROORDEN=f.NroOrden
			Left join DBO.TmpPerfilMotosbancarizado	    g					 
				on a.NROORDEN=g.NroOrden
			Left join DBO.TmpPerfilEfectiNegocio	 	h					 
				on a.NROORDEN=h.NroOrden
			Left join DBO.TmpPerfilTarjetaCredito	 	i					 
				on a.NROORDEN=i.NroOrden
			where a.FecCorteRCC= V_FecCorteRCC and a.FECCORTE=V_FecCorte
			group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21;
			--#@E2E04 Final --  	
      					
		
			-- Cursor de Reperfilado con Riesgo Compartido y Score Equifax
			--#@E2E05 Inicial
		
			DROP TABLE DBO.CUR_REPERFILADO IF EXISTS;
			CREATE Temp table DBO.Cur_Reperfilado 
			AS
			SELECT  
				A.NROORDEN,A.FECCORTE,a.FECCORTERCC,A.CODTIPODOCUMENTO,A.NUMDOCUMENTO,RECELECTRO_CODREP,BKELECTRO_CODREP,a.CODTIPOCLIENTE,
				--Reperfilado
				C.BKELECTRO, C.BKMOTOS, C.BKEFECTIVO, C.RECELECTRO, C.RECMOTOS, C.RECEFECTIVO, C.BKMICRO,
				C.BKTDC,C.RECTDC,--#E2E18
				C.RECEFECTIVOFECCORTE, C.RECEFECTIVOKEYBD,
				C.BKEFECTIVOFECCORTE,  C.BKEFECTIVOKEYBD,
				C.RECELECTROFECCORTE,  C.RECELECTROKEYBD,
				C.BKELECTROFECCORTE,   C.BKELECTROKEYBD,
				C.RECMOTOSFECCORTE,  C.RECMOTOSKEYBD,
				C.BKMOTOSFECCORTE, 	C.BKMOTOSKEYBD,
				C.BKMICROFECCORTE, 	C.BKMICROKEYBD,					
				c.BkTDCFecCorte,	c.BkTDCKeyBd,--#E2E18
				---
				V_Periodo AS PERIODO,				
				a.FLGRIESGOCOMPARTIDO_SCORE AS FLGSCOREEQUIFAX,
				Case when nvl(c.Cod_Indicador,10)<>10 then 'S' else 'N' end FlgRescateANegativo,				
				--#E2E19 Inicio 
				Case when a.CodZonaUbigeo='A' then '1'
					 when a.CodZonaUbigeo='B' then '2'
					 when a.CodZonaUbigeo='C' then '3'
					 when a.CodZonaUbigeo='D' then '4'					
				end CodGrupoEFN,
				
				NVL(C.TipoProceso,3) AS TipoProceso,
				DECODE (c.marca,'REC',2,'BK',1) AS CodClienteEFN,
				DECODE (c.TipoProceso,4,'S','N') AS FlgProSinAtencion,
				--#E2E19 Final 
				Nvl(d.CodTipoProceso,4) CodTipoProcesoEfectivo, nvl(d.CodTipoSubProceso,'0@0@0@6') CodTipoSubProcesoEfectivo --#@E2E28						
			FROM PROD_MODELOS.DBO.UMD_FED_RDGENERAL_SEMANAL A	--#WCA05
			LEFT JOIN DBO.Reperfilado  C
				ON  a.NROORDEN=c.NROORDEN AND a.FECCORTE=c.FECCORTE	
			LEFT JOIN TMP_DETALLEBASEMASIVASPROCESOEFECTIVO D			--#@E2E28
				ON a.NroOrden = d.NroOrden AND PrelacionTipoProceso = 1	--#@E2E28
			WHERE A.FECCORTE= V_FecCorte;	
			--#@E2E05 Final	 
		
			---	 
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then		  		
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			
			end if;
		end;
		end if;		


	
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 2.- Base de aprobados en Electro Bancarizado / Nuevos 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 2;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
		begin
			--- 
			Drop Table DBO.Tempo_EFECTIVO_G5 If Exists;
			CREATE Temp table DBO.Tempo_EFECTIVO_G5
			as
			select 
				a.nroorden,
				--- #@LCB3 Inicio
				max(Case when c.BKELECTRO in ('VP1','VIP1','VP2','VIP2','OK') and b.FLGCALIFDIF100PCTNORMALUR24UM = 'N' Then 'G5' Else 'G99' end) Grupo
				--- #@LCB3 Final
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS a				--#WCA05
			Left Join PROD_MODELOS.DBO.UMD_FED_RDGENERAL_MENSUAL	b			--#WCA05
				on (b.FECCORTERCC = a.FecCorteRCC and b.NroOrden = a.NroOrden)	--#WCA05
			left join DBO.Reperfilado 							 c
				on (c.NroOrden = b.NroOrden)
			LEFT JOIN DBO.TMP_DETALLEBASEMASIVASAPROB			D
				ON (A.NROORDEN=D.NROORDEN)
			where a.PERIODO = V_Periodo and (a.keybd = 123 and a.BDVALUE = 'S') AND D.APRBKSUSTENTO='N' and a.TipoAmbiente=1--11
			Group by a.NroOrden;
			 
			
			--#E2E18
     		Drop Table DBO.Tempo_TC_G5 If Exists;
			CREATE Temp table DBO.Tempo_TC_G5
			as
			select 
				a.nroorden,
				--- #@LCB3 Inicio
				max(Case when c.BKELECTRO in ('VP1','VIP1','VP2','VIP2','OK') and b.FLGCALIFDIF100PCTNORMALUR24UM = 'N' Then 'G5' Else 'G99' end) Grupo
				--- #@LCB3 Final
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS a					--#WCA05
			Left Join PROD_MODELOS.DBO.UMD_FED_RDGENERAL_MENSUAL	b			--#WCA05
				on (b.FECCORTERCC = a.FecCorteRCC and b.NroOrden = a.NroOrden)	--#WCA05
			left join DBO.Reperfilado 							 c
				on (c.NroOrden = b.NroOrden)
			LEFT JOIN DBO.TMP_DetalleBaseMasivaTC			D
				ON (A.NROORDEN=D.NROORDEN)
			where a.PERIODO = V_Periodo and (a.keybd = 123 and a.BDVALUE = 'S') AND D.APRBKTC='N' and a.TipoAmbiente=1--11
			Group by a.NroOrden;
		
     
			---	
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then		  	
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			  
			end if;
		end;
		end if;		
	
	
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 3.- Base de aprobados en Electro Recurrente / Mailing Segmentado. 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 3;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Drop Table DBO.Tempo_EFECTIVO_G7 If Exists;
			CREATE Temp table DBO.Tempo_EFECTIVO_G7 as
			select a.nroorden,
				max(Case when c.RECELECTRO in (1,2,3,4) and  b.FLGCALIFDIF100PCTNORMALUR24UM = 'N' Then 'G7' Else 'G99' end) Grupo-- #@LCB3 Inicio
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS a	--#WCA05
				Left Join PROD_MODELOS.DBO.UMD_FED_RDGENERAL_MENSUAL	b	on (b.FECCORTERCC = a.FecCorteRCC and b.NroOrden = a.NroOrden)	--#WCA05
				left join DBO.Reperfilado 								c	on (c.NroOrden = b.NroOrden)
				left join DBO.TMP_DETALLEBASEMASIVASAPROB				D	on (A.NROORDEN=D.NROORDEN)
			where a.PERIODO = V_Periodo and (a.keybd = 128 and a.BDVALUE = 'S') AND D.APRRECSUSTENTO='N' and a.TipoAmbiente=1 --10
			Group by a.NroOrden;
			--#E2E18
			Drop Table DBO.Tempo_TC_G7 If Exists;
			CREATE Temp table DBO.Tempo_TC_G7 as
			select a.nroorden,
				max(Case when c.RECELECTRO in (1,2,3,4) and  b.FLGCALIFDIF100PCTNORMALUR24UM = 'N' Then 'G7' Else 'G99' end) Grupo -- #@LCB3 Inicio
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS a	--#WCA05
				Left Join PROD_MODELOS.DBO.UMD_FED_RDGENERAL_MENSUAL	b	on b.FECCORTERCC = a.FecCorteRCC and b.NroOrden = a.NroOrden	--#WCA05
				left join DBO.Reperfilado 				C	on c.NroOrden = b.NroOrden
				left join DBO.TMP_DetalleBaseMasivaTC	D	on D.NROORDEN = A.NROORDEN
			where a.PERIODO = V_Periodo and (a.keybd = 128 and a.BDVALUE = 'S') AND D.APRRECTC ='N' and a.TipoAmbiente=1 --10
			Group by a.NroOrden;		     

			V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then		  		
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			    
			end if;
		end if;		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 4.- Base de aprobados en Electro Recurrente Reegnache + Mailing Segmentado 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 4;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Drop Table DBO.Tempo_ELECTRO_G0 if Exists;
			CREATE Temp table DBO.Tempo_ELECTRO_G0 as
			select a.nroorden,'S' as FlgAprueba
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS 	a	--#WCA05
				left join DBO.Reperfilado 						b	on (b.NroOrden = a.NroOrden and b.RecElectroFecCorte=a.FecCorte)
			where a.PERIODO = V_Periodo and a.keybd in (126,128) and a.BDVALUE = 'S' and b.RECELECTRO in (1,2,3,4) and a.TipoAmbiente=1 --9,10
			Group by a.NroOrden;
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');
			end if;
		end if;		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 5.- Base de aprobados en Electro nuevos 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 5;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Drop Table DBO.Tempo_ELECTRO_G1 If Exists;
			CREATE Temp table DBO.Tempo_ELECTRO_G1 as
			select a.nroorden,'S' as FlgAprueba
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS 	a	--#WCA05
				left join DBO.Reperfilado						b on (b.NroOrden = a.NroOrden and b.BkElectroFecCorte=a.FecCorte)
			where a.PERIODO = V_Periodo and a.keybd in (123) and a.BDVALUE = 'S' and b.BKELECTRO in ('VP1','VP2','OK') and a.TipoAmbiente=1 --11
			Group by a.NroOrden;
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			 
			end if;
		end if;		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 6. 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 6;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Drop Table DBO.Tempo_MOTOS_G0 If Exists;
			CREATE Temp table DBO.Tempo_MOTOS_G0 as
			select a.nroorden,'S' as FlgAprueba
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	a	--#WCA05
				left join DBO.TmpV_ReglasDuras_				b	on (b.FecCorte = a.FecCorte and b.NroOrden = a.NroOrden)--#WCA16
				left join DBO.Reperfilado 					c	on (b.NroOrden = c.NroOrden)
			where a.PERIODO = V_Periodo
				and a.keybd in (120) and a.BDVALUE = 'S' and c.RECMOTOS in (1,2,3,4,5,6) and a.TipoAmbiente=1 --13
				and b.IMPCMENUEVODISPONIBLE_MOTOR>=200 
			Group by a.NroOrden;
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			  
			end if;
		end if;
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 7. 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 7;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Drop Table DBO.Tempo_MOTOS_G1 If Exists;
			CREATE Temp table DBO.Tempo_MOTOS_G1 as
			select a.nroorden,'S' as FlgAprueba
			from PROD_MODELOS.DBO.UMD_FED_DETALLEBASEMASIVAS	a	--#WCA05
			    left join DBO.TmpV_ReglasDuras_	b 	on (b.FecCorte = a.FecCorte and b.NroOrden = a.NroOrden)--#WCA16
				left join DBO.Reperfilado		c	on (c.NroOrden = b.NroOrden)
			where a.PERIODO = V_Periodo
				and a.keybd in (119) and a.BDVALUE = 'S' and c.BKMOTOS in ('VP1','VP2') and a.TipoAmbiente=1 --14
				and b.IMPCMEBASESMASIVAS_MOTOR >=200
			Group by a.NroOrden;
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');
			end if;
		end if;
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 8. Procesamiento de la Matriz de Rechazos con las Reglas Duras
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 8;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			DROP TABLE DBO.FED_TMP_RECHAZOS IF EXISTS;		
			CREATE Temp table DBO.FED_TMP_RECHAZOS AS
			SELECT	B.NROORDEN,
				B.CODTIPODOCUMENTO,
				B.NUMDOCUMENTO,
				A.COD_SEGTORIESGO,						
				case WHEN (nvl(b.edad,0)=74 and nvl(b.edadmeses,0)>10) or nvl(b.Edad,0)>74 Then 'S' else 'N' end as FlgEdad, -- #E2E20					
				CASE 
					WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL' 							THEN 'FLG_GENERAL'
					WHEN A.COD_SEGTORIESGO IN ('FLG_ELECTROBK','FLG_ELECTROREC') 	THEN 'ELECTRO'
					WHEN A.COD_SEGTORIESGO IN ('FLG_MOTOSBK','FLG_MOTOSREC') 		THEN 'MOTOS'
					WHEN A.COD_SEGTORIESGO IN ('FLG_EFECTIVOBK','FLG_EFECTIVOREC') 	THEN 'EFECTIVO'
					WHEN A.COD_SEGTORIESGO IN ('FLG_AUTOCONSBK','FLG_AUTOCONSREC') 	THEN 'AUTOCONST'
					WHEN A.COD_SEGTORIESGO IN ('FLG_HIPOTECBK','FLG_HIPOTECREC') 	THEN 'HIPOTEC' 	
					--@E2E04 Inicio
					WHEN A.COD_SEGTORIESGO IN ('FLG_CINTERNOBK','FLG_CEPUBLICOBK','FLG_CEPRIVADOBK')		
																					THEN 'CONVENIO'						
					WHEN A.COD_SEGTORIESGO IN ('FLG_TARJETABK','FLG_TARJETAREC','FLG_TARJETACOL')  	--- #E2E18
																					THEN 'TARJETA'		--- #E2E18											
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK' 					THEN 'EFECTINEGOCIO'
					--@E2E04 Final
				END AS TIP_FILTRO,
					
				CASE WHEN A.IND_ObsRech02 = 'X' AND B.FLGDNIACTIVO						='N' THEN '@obsRech02' ELSE '' END||						
				CASE WHEN A.IND_ObsRech03 = 'X' AND B.FLGREPORTADOLAFT					='S' THEN '@obsRech03' ELSE '' END||
				CASE WHEN A.IND_ObsRech04 = 'X' AND B.FLGARCHNEGATRASOMAY90D0P			='S' THEN '@obsRech04' ELSE '' END||
				CASE WHEN A.IND_ObsRech05 = 'X' AND B.FLGARCHNEGATRASOMAY90D			='S' THEN '@obsRech05' ELSE '' END||
				CASE WHEN A.IND_ObsRech06 = 'X' AND B.FLGARCHNEGCLIENTECBRP				='S' THEN '@obsRech06' ELSE '' END||
				CASE WHEN A.IND_ObsRech07 = 'X' AND B.FLGARCHNEGDEFCREDCASTIG			='S' THEN '@obsRech07' ELSE '' END||
				CASE WHEN A.IND_ObsRech08 = 'X' AND B.FLGARCHNEGINSMOTOSRECH			='S' THEN '@obsRech08' ELSE '' END||
				CASE WHEN A.IND_ObsRech09 = 'X' AND B.FLGARCHNEGRECHDATOSFALSOS			='S' THEN '@obsRech09' ELSE '' END||
				CASE WHEN A.IND_ObsRech10 = 'X' AND B.FLGARCHNEGREGMANUAL				='S' THEN '@obsRech10' ELSE '' END||
				CASE WHEN A.IND_ObsRech12 = 'X' AND B.FLGARCHNEGATRASOMAY15D			='S' THEN '@obsRech12' ELSE '' END||
				--		CASE WHEN A.IND_ObsRech14 = 'X' AND B.FLGREGSITRADOMICROZONAPELIGROSA	='S' THEN '@obsRech14' ELSE '' END|| --#E2E17
				CASE
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK'	 	 AND B.BANCA_EFECTIVO	   	= 'RECH' 				THEN '@obsRech16'						
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_TARJETABK'	 	 AND B.BANCA_TC				in ('OK','RECH')		THEN '@obsRech16' 	-- #E2E18
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK' AND B.BANCA_EFECTINEGOCIO 	IN ('RECH', '') 		THEN '@obsRech16' 	-- #E2E18							
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_ELECTROREC'	 	 AND B.RECELECTRO		   	= 7						THEN '@obsRech16'						
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' 	 AND B.RECEFECTIVO		   	= 7						THEN '@obsRech16'
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_TARJETAREC'	 	 AND B.RECTARJETA 			in ('4','5','6','7')	THEN '@obsRech16' 	-- #E2E18
					WHEN A.IND_ObsRech16 = 'X' AND A.COD_SEGTORIESGO = 'FLG_ELECTROBK'	 	 AND B.BANCA_ELECTRO	   	= 'RECH' 				THEN '@obsRech16'	-- #WCA14
					ELSE '' END||
				CASE WHEN A.IND_ObsRech26 = 'X' AND B.FLGRECHAZADOLISTANEGRA			='S' THEN '@obsRech26' ELSE '' END||
				CASE WHEN A.IND_ObsRech27 = 'X' AND B.FLGRECHAZOSOE_MOTOR				='S' THEN '@obsRech27' ELSE '' END||
				CASE
	--				WHEN A.IND_ObsRech28 <> 'X'																																									       THEN ''
	--				--- #@LCB1 Inicio
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.BANCA_ELECTRO = 'VP1'										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				--- #@LCB1 Fin																							
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.BANCA_ELECTRO = 'VP2'										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.BANCA_ELECTRO = 'OK'										AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.BANCA_ELECTRO IN ('OB1','OB2','OB3')						AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECELECTRO IN (1,2)										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECELECTRO IN (3,4)										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECELECTRO IN (5,6)										AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				--@E2E04 Inicio																							
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.BANCA_MOTOS = 'VP1' 										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.BANCA_MOTOS = 'VP2' 										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.BANCA_MOTOS = 'OK' 										AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.BANCA_MOTOS IN ('OB1','OB2','OB3') 						AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECMOTOS IN (1,2) 										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECMOTOS IN (3,4) 										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECMOTOS IN (5,6)  						   				AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''							
	--				--@E2E04 Fin																							
	--			
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.BANCA_EFECTIVO IN ('VP1','VP2','OK')						AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECEFECTIVO IN (1,2)										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND B.RECEFECTIVO IN (3,4)										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--			
	--				--@E2E04 Inicio
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.BANCA_TC IN ('VP1','VP2','OK')							AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	-- #E2E18
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.RECTARJETA IN ('1','2')	      							AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	-- #E2E18																
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'	AND	B.RECTARJETA IN ('3','4')	      							AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	-- #E2E18																
	--				
    --         		WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL' 	AND B.BANCA_CONVENIO IN ('VP1','VP2','OK','OB1','OB2','OB3')	AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
	--			
	--				WHEN A.COD_SEGTORIESGO = 'FLG_GENERAL'  AND B.BANCA_EFECTINEGOCIO IN ('ELT','PRF','ESP')			AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --CAMBIO
					--@E2E04 Final
					--#@MLA29 Inicio
					WHEN A.IND_ObsRech28 <> 'X'																																									   			   THEN ''					
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROBK'	AND B.BANCA_ELECTRO = 'VP1'										AND 8 /*+ (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END)*/ >= B.NROENTIDADESREPORTANTES THEN ''																										
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROBK'	AND B.BANCA_ELECTRO = 'VP2'										AND 6 /*+ (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END)*/ >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROBK'	AND B.BANCA_ELECTRO = 'OK'										AND 5 /*+ (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END)*/ >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROBK'	AND B.BANCA_ELECTRO IN ('OB1','OB2','OB3')						AND 4 /*+ (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END)*/ >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROREC'	AND B.RECELECTRO IN (1,2)										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROREC'	AND B.RECELECTRO IN (3,4)										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_ELECTROREC'	AND B.RECELECTRO IN (5,6)										AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''																										
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSBK'		AND	B.BANCA_MOTOS = 'VP1' 										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSBK'		AND	B.BANCA_MOTOS = 'VP2' 										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSBK'		AND	B.BANCA_MOTOS = 'OK' 										AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSBK'		AND	B.BANCA_MOTOS IN ('OB1','OB2','OB3') 						AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSREC'		AND B.RECMOTOS IN (1,2) 										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSREC'		AND B.RECMOTOS IN (3,4) 										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_MOTOSREC'		AND B.RECMOTOS IN (5,6)  						   				AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''		
				
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK'	AND B.BANCA_EFECTIVO IN ('VP1','VP2','OK')						AND 5 /*+ (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END)*/ >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC'	AND B.RECEFECTIVO IN (1,2)										AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC'	AND B.RECEFECTIVO IN (3,4)										AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''				
					
					WHEN A.COD_SEGTORIESGO = 'FLG_TARJETABK'	AND	B.BANCA_TC IN ('VP1','VP2','OK')							AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	-- #E2E18
					WHEN A.COD_SEGTORIESGO = 'FLG_TARJETAREC'	AND	B.RECTARJETA IN ('1','2')	      							AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	-- #E2E18																
					WHEN A.COD_SEGTORIESGO = 'FLG_TARJETAREC'	AND	B.RECTARJETA IN ('3','4')	      							AND 5 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''	-- #E2E18																
					
              		WHEN A.COD_SEGTORIESGO IN ('FLG_CINTERNOBK','FLG_CEPUBLICOBK','FLG_CEPRIVADOBK')	
              			 AND B.BANCA_CONVENIO IN ('VP1','VP2','OK','OB1','OB2','OB3')											AND 6 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''
				
		--			WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ELT','PRF')					AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --CAMBIO									
		--			WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ESP','POT')					AND 2 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''		
		--			WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ELT','PRF') AND B.CodClienteEFN=1	AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --CAMBIO									
		--			WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ESP','POT') AND B.CodClienteEFN=1	AND 2 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' 	
		--			WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ELT','PRF') AND B.CodClienteEFN=2	AND 4 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' 	--CAMBIO									
		--			WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ESP','POT') AND B.CodClienteEFN=2	AND 3 + (CASE WHEN B.FLGREPORTADOEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN ''  		 
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ELT','PRF') AND B.CodClienteEFN=1	AND 3 + (CASE WHEN B.FlgDeudaActualEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --#@E2E29									
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ESP','POT') AND B.CodClienteEFN=1	AND 2 + (CASE WHEN B.FlgDeudaActualEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --#@E2E29
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ELT','PRF') AND B.CodClienteEFN=2	AND 4 + (CASE WHEN B.FlgDeudaActualEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --#@E2E29									
					WHEN A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'  AND B.BANCA_EFECTINEGOCIO IN ('ESP','POT') AND B.CodClienteEFN=2	AND 3 + (CASE WHEN B.FlgDeudaActualEFE = 'S' THEN 1 ELSE 0 END) >= B.NROENTIDADESREPORTANTES THEN '' --#@E2E29
					--#@MLA29 Final					
					ELSE '@obsRech28' END||
				CASE WHEN A.IND_ObsRech29 = 'X' AND B.FLGDEUDADUDPERCAS60UM				='S' THEN '@obsRech29' ELSE '' END||
				CASE WHEN A.IND_ObsRech30 = 'X' AND B.FLGCTACTECERRADA					='S' THEN '@obsRech30' ELSE '' END||
				CASE WHEN A.IND_ObsRech31 = 'X' AND B.FLG2OMASTARJETASANU				='S' THEN '@obsRech31' ELSE '' END||
				CASE WHEN A.IND_ObsRech32 = 'X' AND B.FLGDEUDAREESTRUCTURADAUM			='S' THEN '@obsRech32' ELSE '' END||
				CASE WHEN A.IND_ObsRech33 = 'X' AND B.FLGDEUDAREFINANCIADAUM			='S' THEN '@obsRech33' ELSE '' END||
				CASE WHEN A.IND_ObsRech34 = 'X' AND B.FLGDEUDAJUDICIALUM				='S' THEN '@obsRech34' ELSE '' END||
				CASE WHEN A.IND_ObsRech35 = 'X' AND B.FLGDEUDACASTIGOUM					='S' THEN '@obsRech35' ELSE '' END||
				CASE WHEN A.IND_ObsRech21 = 'X' AND B.FLGDEUDACASTIGOUM					='S' THEN '@obsRech21' ELSE '' END||	--#WCA10
				---CASE WHEN A.IND_ObsRech36 = 'X' AND B.FLGDEUDAREPROGRAMADA				='S' THEN '@obsRech36' ELSE '' END||
				CASE WHEN A.IND_ObsRech36 = 'X' AND B.FlgReprogramadoSSFF				='S' THEN '@obsRech36' ELSE '' END|| --#@E2E29
				--	CASE WHEN A.IND_ObsRech37 = 'X' AND B.FLGDEUDAREPROGRAMADA12UM			='S' THEN '@obsRech37' ELSE '' END||	--#E2E21
				CASE WHEN A.IND_ObsRech38 = 'X' AND B.FLGCALIFDIF100PCTNORMALUR24UM		='S' THEN '@obsRech38' ELSE '' END||
				CASE WHEN A.IND_ObsRech40 = 'X' AND B.FLGCALIFMAYCPP3UR24UM				='S' THEN '@obsRech40' ELSE '' END||
				CASE WHEN A.IND_ObsRech41 = 'X' AND B.FLGCALIFMAYCPP6UR24UM				='S' THEN '@obsRech41' ELSE '' END||
				CASE WHEN A.IND_ObsRech42 = 'X' AND B.FLGCALIFMAYCPP24UM				='S' THEN '@obsRech42' ELSE '' END||
				CASE WHEN A.IND_ObsRech44 = 'X' AND B.FLGREPROGRAMADO					='S' THEN '@obsRech44' ELSE '' END||
				CASE WHEN A.IND_ObsRech48 = 'X' AND B.FLGREFINANCIADO					='S' THEN '@obsRech48' ELSE '' END||
				CASE
				
					--@E2E04 Inicio
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO = 'FLG_ELECTROBK' 						 AND (B.EDAD > 75 OR B.EDAD < 18) THEN '@obsRech55'
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO = 'FLG_ELECTROREC'		 				 AND (B.EDAD > 74 OR B.EDAD < 18) THEN '@obsRech55'							
					--@E2E04 Final																															
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO IN ('FLG_MOTOSBK','FLG_MOTOSREC')		 AND (B.EDAD > 73 OR B.EDAD < 21) THEN '@obsRech55'
										
				--	WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK'						 AND (B.EDAD > 74 OR B.EDAD < 25) THEN '@obsRech55'
				--	WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC'					 AND (B.EDAD > 74 OR B.EDAD < 20) THEN '@obsRech55'	
					WHEN A.IND_ObsRech49 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK' 					 AND (B.EDAD < 25) 				  THEN '@obsRech49'	-- #E2E20
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK' 					 AND (FlgEdad='S') 				  THEN '@obsRech55'	-- #E2E20					
					WHEN A.IND_ObsRech49 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' 					 AND (B.EDAD < 20) 				  THEN '@obsRech49'	-- #E2E20
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' 					 AND (FlgEdad='S') 				  THEN '@obsRech55'	-- #E2E20						
					
					--@E2E04 Inicio																															
					--WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO ='FLG_EFECTINEGOCIOBK'	 				 AND (B.EDAD > 75 OR B.EDAD < 21) THEN '@obsRech55'							
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO ='FLG_EFECTINEGOCIOBK'	 AND B.FlgRechazoEdad = 'S' THEN '@obsRech55'	--#E2E29 Se considera “<21 y >74 10 MESES" en lugar de “<21 y > 75”
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO IN ('FLG_CINTERNOBK','FLG_CEPUBLICOBK',												
																						'FLG_CEPRIVADOBK',
																						'FLG_TARJETACOL') 	 AND (B.EDAD > 74 OR B.EDAD < 18) THEN '@obsRech55'--- #E2E18
					
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO ='FLG_TARJETABK' 	 AND (B.EDAD > 74 OR B.EDAD < 22) THEN '@obsRech55'	--- #E2E18	
					WHEN A.IND_ObsRech55 = 'X' AND A.COD_SEGTORIESGO ='FLG_TARJETAREC' 	 AND (B.EDAD > 74 OR B.EDAD < 22) THEN '@obsRech55'	--- #E2E18	
					--@E2E04 Final
					ELSE '' END||
				CASE WHEN A.IND_ObsRech58 = 'X' AND B.FLGMOROSIDADEFEMAY60DIAS12UM		='S' THEN '@obsRech58' ELSE '' END||
				CASE WHEN A.IND_ObsRech59 = 'X' AND B.FLGHASTACPP4_12UR24UM				='S' THEN '@obsRech59' ELSE '' END||
				CASE WHEN A.IND_ObsRech60 = 'X' AND B.FLGCalifDif100Normal03UM			='S' THEN '@obsRech60' ELSE '' END||					
				CASE
					WHEN A.IND_ObsRech66 = 'X' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' AND B.RECEFECTIVO	IN (2,3,4) AND B.FLGPROVINCIAIQUITOS ='S' THEN '@obsRech66'	
					WHEN A.IND_ObsRech66 = 'X' AND A.COD_SEGTORIESGO = 'FLG_TARJETAREC' AND B.RECTARJETA	IN ('2','3','4') AND B.FLGPROVINCIAIQUITOS ='S' THEN '@obsRech66'	--- #E2E18					
					ELSE '' END||
				CASE WHEN A.IND_ObsRech79 = 'X' AND B.FLGDEUDAREESTRUCTURADA12UM		='S' THEN '@obsRech79' ELSE '' END||
				CASE WHEN A.IND_ObsRech80 = 'X' AND B.FLGDEUDAREFINANCIADA12UM			='S' THEN '@obsRech80' ELSE '' END||
				CASE WHEN A.IND_ObsRech81 = 'X' AND B.FLGDEUDAJUDICIAL12UM				='S' THEN '@obsRech81' ELSE '' END||
				CASE WHEN A.IND_ObsRech82 = 'X' AND B.FLGDEUDACASTIGO6UR24UM			='S' THEN '@obsRech82' ELSE '' END||
				CASE WHEN A.IND_ObsRech83 = 'X' AND B.FLGDEUDACASTIGO24UM				='S' THEN '@obsRech83' ELSE '' END||
				
				
				--- #02WCA Inicio
				CASE WHEN A.IND_ObsRech86 = 'X' AND B.FLGDEUDACASTIGO3UR6UM				='S' THEN '@obsRech86' ELSE '' END||
				CASE WHEN A.IND_ObsRech87 = 'X' AND B.FLGCALIFMAYCPP3UR6UM				='S' THEN '@obsRech87' ELSE '' END||
				
				
				CASE WHEN A.IND_ObsRech23 = 'X' AND B.FLGCALIFDIF100PCTNORMALUR6UM		='S' THEN '@obsRech23' ELSE '' END||
				--- #02WCA Final
				--@E2E04 Inicio					
				--	CASE WHEN A.IND_ObsRech117 = 'X' AND B.FLGDEUDACASTIGO12UM				='S' THEN '@obsRech117' ELSE '' END||
				CASE WHEN A.IND_ObsRech108 = 'X' AND B.FLGCALIFMAYCPPUM					='S' THEN '@obsRech108' ELSE '' END||
				CASE WHEN A.IND_ObsRech100 = 'X' AND B.FLGDIASATRASO3UR6UM				='S' THEN '@obsRech100' ELSE '' END||
				CASE WHEN A.IND_ObsRech101 = 'X' AND B.FLGNROREPCPP6UR12UM				='S' THEN '@obsRech101' ELSE '' END||
				CASE WHEN A.IND_ObsRech102 = 'X' AND B.FLGMICROPEQEMPRESA24UM			='S' THEN '@obsRech102' ELSE '' END||
				CASE WHEN A.IND_ObsRech103 = 'X' AND B.FLGREGLAEXPERIENCIA				='S' THEN '@obsRech103' ELSE '' END||
				CASE WHEN A.IND_ObsRech104 = 'X' AND B.FLGDEUDAMICPEQMAY100KUM			='S' THEN '@obsRech104' ELSE '' END||
				CASE WHEN A.IND_ObsRech105 = 'X' AND B.FLGRATIODEUDA6K					='S' THEN '@obsRech105' ELSE '' END||						
				CASE WHEN A.IND_ObsRech106 = 'X' AND B.FLGDEUDACASTIGO60UM				='S' THEN '@obsRech106' ELSE '' END||						
				CASE WHEN A.IND_ObsRech107 = 'X' AND B.FLGCASTIGOFEMEN2					='S' THEN '@obsRech107' ELSE '' END||	
				CASE WHEN A.IND_ObsRech109 = 'X' AND B.FLGCALIFMAYNORMALUM_MAYCPP5MA	='S' THEN '@obsRech109' ELSE '' END||  
				CASE WHEN A.IND_ObsRech110 = 'X' AND B.FLGRECHAZOSOECFMMAYLEM			='S' THEN '@obsRech110' ELSE '' END||
				CASE WHEN A.IND_ObsRech111 = 'X' AND B.FLGDEUDACASTIGO60UM				='S' THEN '@obsRech111' ELSE '' END|| 
				CASE WHEN A.IND_ObsRech112 = 'X' AND B.CALIFDIFNORMAL_NOREPORTADO12UM	='S' THEN '@obsRech112' ELSE '' END||  
				CASE WHEN A.IND_ObsRech113 = 'X' AND B.FLG30DIASATRASO6UM				='S' THEN '@obsRech113' ELSE '' END|| 
				CASE WHEN A.IND_ObsRech114 = 'X' AND B.FlgDeudaVencida6UM				='S' THEN '@obsRech114' ELSE '' END|| 
				CASE WHEN A.IND_ObsRech115 = 'X' AND B.FLGNROTCMAYUM					='S' THEN '@obsRech115' ELSE '' END|| 
				CASE WHEN A.IND_ObsRech116 = 'X' AND B.FLGSINTCUM						='S' THEN '@obsRech116' ELSE '' END||  
				--	CASE WHEN A.IND_ObsRech120 = 'X' AND B.FlgReprogramadoCOVID19			='S' THEN '@obsRech120' ELSE '' END||						
				CASE WHEN A.IND_ObsRech121 = 'X' AND B.MrcOficioRiesgo					='S' THEN '@obsRech121' ELSE '' END||						
				
				--- #E2E15 Inicio
				CASE WHEN A.IND_ObsRech139 = 'X' AND B.Rechazo_RECORDCREDITICIO12UM		='S' THEN '@obsRech139' ELSE '' END||
				CASE WHEN A.IND_ObsRech140 = 'X' AND B.FLGDEFDUDPER24UM					='S' THEN '@obsRech140' ELSE '' END||
				--- #E2E15 Final
				CASE WHEN A.IND_ObsRech147 = 'X' AND B.FLGPCTCALIFCPPMAYOR20			='S' THEN '@obsRech147' ELSE '' END||
				--	CASE WHEN A.IND_ObsRech148 = 'X' AND B.FLGTIENETDCULTRCC 				='N'
				--									 AND B.GRUPOB IS NOT NULL 				THEN '@obsRech148' ELSE '' END||		--#@E2E24
				--#@E2E05 Inicio						
				CASE --WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX					='S' THEN '@obsRech18'  
--					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK'  AND B.BANCA_EFECTIVO NOT IN ('VP1','VP2')  	THEN '@obsRech18'
--					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' AND B.RECEFECTIVO 	NOT IN (1,2,3,5,6)  	THEN '@obsRech18'
--					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_ELECTROBK'   AND B.BANCA_ELECTRO 	NOT IN ('VP1','VP2')  	THEN '@obsRech18'
--					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_ELECTROREC'  AND B.RECELECTRO 	NOT IN (1,2,3)   		THEN '@obsRech18'
--					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_MOTOSBK'     AND B.BANCA_MOTOS 	NOT IN ('VP1','VP2')  	THEN '@obsRech18'
--					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_MOTOSREC'    AND B.RECMOTOS 		NOT IN (1,2,3)   		THEN '@obsRech18'						
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_ EFECTIVOBK'  AND B.BANCA_EFECTIVO NOT IN ('VP1','VP2')  	THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' AND B.RECEFECTIVO 	NOT IN (1,2,3,5,6)  	THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_TARJETABK'   AND B.BANCA_TC		NOT IN ('VP1','VP2')  	THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_TARJETAREC'  AND B.RECTARJETA 	NOT IN ('1','2','3','5','6')  	THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_ELECTROBK'   AND B.BANCA_ELECTRO 	NOT IN ('VP1','VP2')  	THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_ELECTROREC'  AND B.RECELECTRO 	NOT IN (1,2,3)   		THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_MOTOSBK'     AND B.BANCA_MOTOS 	NOT IN ('VP1','VP2')  	THEN '@obsRech20' --#WCA13
					 WHEN A.IND_ObsRech18  = 'X' AND B.FLGSCOREEQUIFAX	='S' AND A.COD_SEGTORIESGO = 'FLG_MOTOSREC'    AND B.RECMOTOS 		NOT IN (1,2,3)   		THEN '@obsRech20' --#WCA13						
				ELSE '' END||						
				--#@E2E05 Final					
				CASE WHEN A.IND_ObsRech125 = 'X' AND B.FLGPILOTORCOMPEM			='S' THEN '@obsRech125' ELSE '' END|| 
				CASE WHEN A.IND_ObsRech162 = 'X' AND B.FlgProSinAtencion		='S' THEN '@obsRech162' ELSE '' END||	--#E2E19
				CASE WHEN A.IND_ObsRech166 = 'X' AND B.FlgRescateANegativo='S' 	AND B.RECEFECTIVO IN (3,4)	THEN '@obsRech166' ELSE '' END||	--#E2E23
				CASE WHEN A.IND_ObsRech167 = 'X' AND (B.NROREPORTANTENOREGULADA>=2 
												 OR b.CANTDOCMOROSOS>=5 
												 OR b.FLGDEUDACASTIGO24UM 		='S') THEN '@obsRech167' ELSE '' END||	--#E2E23
				CASE WHEN A.IND_ObsRech168 = 'X' AND (B.NROREPORTANTENOREGULADA>=2 OR b.CANTDOCMOROSOS>=20 OR (B.FLGDEUDACASTIGO24UM='S'  AND B.RECEFECTIVO IN (3,4)) )		THEN '@obsRech168' ELSE '' END||	--#E2E23												 
				--		CASE WHEN A.IND_ObsRech169 = 'X' AND (B.FLGNROREPORTE18UM_VP2OK 	='S' or b.NROMESESREPORTADOSSF24UM<=10) THEN '@obsRech169' ELSE '' END||	--#E2E23
				CASE WHEN A.IND_ObsRech169 = 'X' AND ((B.NROMESESREPORTADOSSF18UM<=17 AND B.BANCA_EFECTIVO IN ('VP2','OK'))	
												 or b.NROMESESREPORTADOSSF24UM<=10) THEN '@obsRech169' ELSE '' END||	--#E2E23
				
				CASE WHEN A.IND_ObsRech170 = 'X' AND B.CodReglaToxico=1 AND B.RECEFECTIVO IN (2,3,4) THEN '@obsRech170' ELSE '' END||	--#E2E23
				CASE WHEN A.IND_ObsRech171 = 'X' AND B.CodArrendado=1 	AND B.RECEFECTIVO IN (2,3,4) THEN '@obsRech171' ELSE '' END||	--#E2E23
				--		CASE WHEN A.IND_ObsRech172 = 'X' AND B.FLGINDEARRENDADO_OK 		='S' 				 THEN '@obsRech172' ELSE '' END||	--#E2E23
				CASE WHEN A.IND_ObsRech172 = 'X' AND (B.CodIndeArrendado=1 
												 AND B.BANCA_EFECTIVO IN ('OK'))					 THEN '@obsRech172' ELSE '' END||	--#E2E23
				CASE WHEN A.IND_ObsRech173 = 'X' AND B.CodFamiliar=1 AND B.RECEFECTIVO IN (3,4) 	 THEN '@obsRech173' ELSE '' END||	--#E2E23
				
				CASE WHEN A.IND_ObsRech174 = 'X' AND B.FlgNroReporte24UM_RecScore557='S' 			 THEN '@obsRech174' ELSE '' END||	--#E2E23					
				CASE WHEN A.IND_ObsRech184 = 'X' AND B.FlgImpulsa				='S' 				 THEN '@obsRech184' ELSE '' END||	--#E2E22
				
				CASE WHEN A.IND_ObsRech185 = 'X' AND B.BANCA_EFECTIVO IN ('OK')  		AND b.CANTDOCMOROSOS>1 			THEN '@obsRech185' ELSE '' END||	--#E2E24
				CASE WHEN A.IND_ObsRech186 = 'X' AND B.BANCA_EFECTIVO IN ('VP1','VP2') 	AND b.DEUDATOTALSICOM>505.58	THEN '@obsRech186' ELSE '' END||	--#E2E24
				CASE WHEN A.IND_ObsRech187 = 'X' AND B.BANCA_EFECTIVO IN ('VP1','VP2')  AND 314.300>b.DEUDATOTALSICOM 
																						AND b.DEUDATOTALSICOM>192.500 	THEN '@obsRech187' ELSE '' END||	--#E2E24
				CASE WHEN A.IND_ObsRech188 = 'X' AND B.RECEFECTIVO IN (1)				AND b.DEUDATOTALSICOM>114.990 
																						AND b.NROENTIDADESSICOM>=3 		THEN '@obsRech188' ELSE '' END||	--#E2E24
				CASE WHEN A.IND_ObsRech189 = 'X' AND B.RECEFECTIVO IN (2,3)				AND b.DEUDATOTALSICOM>505.580 
																						AND b.ANTIGUEDADVEHICULAR>=1 	THEN '@obsRech189' ELSE '' END||	--#E2E24 
				CASE WHEN A.IND_ObsRech194 = 'X' AND B.BANCA_EFECTIVO IN ('OK')  		AND b.CANTDOCMOROSOS>0 			THEN '@obsRech194' ELSE '' END||	--#MLA26
				CASE WHEN A.IND_ObsRech195 = 'X' AND B.BANCA_EFECTIVO IN ('VP2') AND b.CANTDOCMOROSOS>0 and b.CNTINMUEBLES=0 THEN '@obsRech195' ELSE '' END||
				CASE WHEN A.IND_ObsRech196 = 'X' AND b.CODZONACOBRANZA=1												THEN '@obsRech196' ELSE '' END ||  --
				CASE WHEN A.IND_ObsRech210 = 'X' AND B.FLGREPORTADOGRUPOESPECIAL = 'S'  	THEN '@obsRech210' ELSE '' END ||
				--CASE WHEN A.IND_ObsRech210 = 'X' AND B.FLGREPORTADOGRUPOESPECIAL = 'S'  	THEN '@obsRech210' ELSE '' END
					--#@CSR28
				CASE WHEN A.IND_ObsRech211 = 'X' AND IsNull(B.FlgRechazoRatioUsoTdc,'N') = 'S' THEN '@obsRech211' ELSE '' END || --#@E2E29
				CASE WHEN A.IND_ObsRech212 = 'X' AND  B.FlgRechazoScoreCobranzaMotosEfecti = 'S' THEN '@obsRech212' ELSE '' END ||  --#@E2E29
				CASE WHEN A.IND_ObsRech213 = 'X' AND B.FlgBkScoreRP3 = 'S' THEN '@obsRech213' ELSE '' END || --#@E2E29
				CASE WHEN A.IND_ObsRech214 = 'X' AND B.FlgReglaRiesgoso = 'S' THEN '@obsRech214' ELSE '' END || --#@E2E29 
				CASE WHEN A.IND_ObsRech215 = 'X' And (B.CodClienteEFN = 1   AND B.FLGCLIENTEALTORIESGO  = 'S') THEN '@obsRech215' ELSE '' END ||--#@E2E29
				CASE WHEN A.IND_ObsRech216 = 'X' And B.FlgConDeudaMedianaEMP_UM = 'S' THEN '@obsRech216' ELSE '' END ||  --#@E2E29
				CASE WHEN A.IND_ObsRech217 = 'X' And B.FlgReproVigenteMenos6UM = 'S' THEN '@obsRech217' ELSE '' END   --#@E2E29  
				
				---@E2E04 Final						 
				AS DES_FILTROREGLA,
				B.FLGTIPOCLIENTEEFE,						
				--		B.CodGrupoEFN			,	--#E2E19
				B.GRUPOEFECTINEGOCIO	,
				B.CodClienteEFN			,	--#E2E19
				B.FlgProSinAtencion		,	--#E2E19
				B.TipoProceso			,	--#E2E19						
				B.BANCA_ELECTRO,
				B.BANCA_MOTOS,
				B.BANCA_EFECTIVO,				
				--- #E2E04 Inicio
				B.BANCA_HIPOTECARIO,-----
				B.BANCA_TC, 			-- TC
				B.BANCA_EFECTINEGOCIO,  -- EfectiNegocio
				B.BANCA_CONVENIO, 		--Convenio
				--- #E2E04 Final
				B.RECELECTRO,
				B.RECMOTOS,
				B.RECEFECTIVO,
				B.RECTARJETA,
				B.RECMICRO,
				B.RECCONVENIO,			
				--B.APRRECEFECTIVA , -----
				--B.APRBKEFECTIVA,------
				B.GRUPOEFECTIVO,
				B.GRUPOTC,
				B.BKNROVERSIONMODELO,
				B.RECNROVERSIONMODELO,	
				B.CODVERSIONBKELECTRO			,	--#@MLA27
				B.CODVERSIONBKMOTOS				,	--#@MLA27
				B.CODVERSIONBKEFECTIVO			,	--#@MLA27
				B.CODVERSIONBKHIPOTECARIO		,	--#@MLA27
				B.CODVERSIONBKEFECTINEGOCIO		,	--#@MLA27
				B.CODVERSIONBKCONVENIO			,	--#@MLA27
				B.CODVERSIONRECELECTRO			,	--#@MLA27
				B.CODVERSIONRECMOTOS			,	--#@MLA27
				B.CODVERSIONRECEFECTIVO			,	--#@MLA27
				B.CODVERSIONRECHIPOTECARIO		,	--#@MLA27
				B.CODVERSIONRECEFECTINEGOCIO	,	--#@MLA27
				B.CODVERSIONRECCONVENIO			,	--#@MLA27						
				B.RECSCOREELECTRO	, --#@MLA27
				B.RECSCOREMOTOS		, --#@MLA27
				B.RECSCOREEFECTIVO	, --#@MLA27
				B.BKSCOREELECTRO	, --#@MLA27
				B.BKSCOREMOTOS		, --#@MLA27
				B.BKSCOREEFECTIVO	, --#@MLA27
				B.SCOREMICRO		, --#@MLA27						
				isnull(B.BKSCORE,0) as BKSCORE,
				B.RECSCORE,
				B.FECCORTE,
				B.FECCORTERCC,
				--- #E2E04 Inicio
				B.FLG_RECAL_SEG,
				B.FLG_RECAL_ING,						
				B.RECEFECTIVOFECCORTE,
				B.RECEFECTIVOKEYBD,
				B.BKEFECTIVOFECCORTE,
				B.BKEFECTIVOKEYBD,
				B.RECELECTROFECCORTE,
				B.RECELECTROKEYBD,
				B.BKELECTROFECCORTE,
				B.BKELECTROKEYBD,
				B.RECMOTOSFECCORTE,
				B.RECMOTOSKEYBD,
				B.BKMOTOSFECCORTE,
				B.BKMOTOSKEYBD,
				B.BKMICROFECCORTE,
				B.BKMICROKEYBD,
				B.CODTIPOPROCESOEFECTIVO, 	--#@E2E28
				B.CODTIPOSUBPROCESOEFECTIVO	--#@E2E28
				--- #E2E04 Final
			FROM PROD_MODELOS.DBO.UMD_FED_MATRIZRECHAZOPIVOT A 
				CROSS JOIN 
				(	SELECT	V.NROORDEN, V.CODTIPODOCUMENTO, V.NUMDOCUMENTO, V.FLGDNIACTIVO,						
						CASE WHEN V.FLGTIPOCLIENTEEFE = 'REC' THEN 2 ELSE 1 END AS FLGTIPOCLIENTEEFE,
						CASE WHEN ISNULL(C.APRRECEFECTIVA,'N') = 'S' 	THEN 'G0'
							WHEN  ISNULL(C.APRBKEFECTIVA,'N') = 'S' 	THEN 'G1'
							--E2E INICIO									
							WHEN  ISNULL(C.APRRECSUSTENTO,'N') = 'S' 	THEN 'G8'	
							WHEN  ISNULL(C.APRBKSUSTENTO,'N') = 'S' 	THEN 'G9'
							WHEN  ISNULL(C.APRNBKEFECTIVA,'N') = 'S' 	THEN 'G10'
							--E2E FINAL
							--- #01WCA Inicial
							WHEN V.FLGTIPOCLIENTEEFE = 'BK'				Then isnull(d.Grupo,'G99')   --G5            
							WHEN V.FLGTIPOCLIENTEEFE = 'REC'			Then isnull(e.Grupo,'G99')	 --G7
							--- #01WCA Final
							ELSE 'G99'
						END GRUPOEFECTIVO,
						CASE WHEN ISNULL(TM.APRRECTC,'N') = 'S' 		THEN 'G0'
							WHEN ISNULL(TM.APRBKTC,'N') = 'S' 			THEN 'G1'
							WHEN V.FLGTIPOCLIENTEEFE = 'BK'				Then isnull(TA.Grupo,'G99')   --G5            
							WHEN V.FLGTIPOCLIENTEEFE = 'REC'			Then isnull(TB.Grupo,'G99')	 --G7
							--- #01WCA Final
							ELSE 'G99'
						END GRUPOTC,
						V.FLGREPORTADOLAFT,
						V.FLGARCHNEGATRASOMAY90D0P,
						V.FLGARCHNEGATRASOMAY90D,
						V.FLGARCHNEGCLIENTECBRP,
						V.FLGARCHNEGDEFCREDCASTIG,
						V.FLGARCHNEGINSMOTOSRECH,
						V.FLGARCHNEGRECHDATOSFALSOS,
						V.FLGARCHNEGREGMANUAL,
						V.FLGARCHNEGATRASOMAY15D,
						V.FLGREGSITRADOMICROZONAPELIGROSA,													
						R.BKELECTRO as BANCA_ELECTRO,
						R.BKMOTOS 	as BANCA_MOTOS,
						--- #@LCB3 Inicio, grupo 5 BK, solo considera VIP1, VIP2 y OK.
						CASE WHEN GRUPOEFECTIVO = 'G5' THEN R.BKELECTRO ELSE R.BKEFECTIVO END BANCA_EFECTIVO, --BKEFECTIVO,
						--- #@LCB3 Fin								
						--- #E2E04 Inicio
						''  BANCA_HIPOTECARIO, --Hipotecario
						CASE WHEN GRUPOTC = 'G5' THEN R.BKELECTRO ELSE R.BKTDC END BANCA_TC, --- #E2E18			
						R.BKMICRO 		as BANCA_EFECTINEGOCIO, -- EfectiNegocio
						V.BKCONVENIO 	as BANCA_CONVENIO, 		--- Convenio		
						V.FLGDEUDACASTIGO12UM,		
						V.FLGCALIFMAYCPPUM,
						V.FLGDIASATRASO3UR6UM,
						V.FLGNROREPCPP6UR12UM,		
						V.FLGMICROPEQEMPRESA24UM,	
						V.FLGReglaExperiencia,		
						V.FLGDEUDAMICPEQMAY100KUM,	
						V.FlgRatiodeuda6K,								
						V.FLGDEUDACASTIGO60UM,
						V.FLGCASTIGOFEMEN2,
						V.FLGRECHAZOSOECFMMAYLEM,
						V.FlgReprogramadoCOVID19,
						V.MrcOficioRiesgo,
						V.FLGCALIFMAYNORMALUM_MAYCPP5MA,
						V.CALIFDIFNORMAL_NOREPORTADO12UM,
						V.FLG30DIASATRASO6UM,		
						V.FlgDeudaVencida6UM,		
						V.FLGNROTCMAYUM,			
						V.FLGSINTCUM,										
						V.FLGPILOTORCOMPEM,								
						--- #E2E04 Final
						V.FLGRECHAZADOLISTANEGRA,
						V.FLGRECHAZOSOE_MOTOR,
						V.FLGREPORTADOEFE,
						V.NROENTIDADESREPORTANTES,
						R.RECELECTRO,
						R.RECMOTOS,
						--- #@LCB3 Inicio, Grupo 7 REC solo considera Recurrencia del 1 al 4.
						CASE WHEN GRUPOEFECTIVO = 'G7' THEN R.RECELECTRO ELSE R.RECEFECTIVO END RECEFECTIVO,
						--- #@LCB3 Fin
						--E2E04 Inicio
						CASE WHEN GRUPOTC 		= 'G7' THEN cast(R.RECELECTRO AS VARCHAR(5)) ELSE R.RECTDC END RECTARJETA,-- #E2E18
						--E2E04 Final
						R.RECEFECTIVO AS RECMICRO,
						V.RECCONVENIO,							
						V.FLGDEUDADUDPERCAS60UM,
						V.FLGCTACTECERRADA,
						V.FLG2OMASTARJETASANU,
						V.FLGDEUDAREESTRUCTURADAUM,
						V.FLGDEUDAREFINANCIADAUM,
						V.FLGDEUDAJUDICIALUM,
						V.FLGDEUDACASTIGOUM,
						V.FLGDEUDAREPROGRAMADA,						
						V.FlgReprogramadoSSFF,	-- #E2E20
						V.FLGDEUDAREPROGRAMADA12UM,
						V.FLGCALIFDIF100PCTNORMALUR24UM,
						V.FLGCALIFMAYCPP1UR24UM,
						V.FLGCALIFMAYCPP3UR24UM,
						V.FLGCALIFMAYCPP6UR24UM,
						V.FLGCALIFMAYCPP24UM,
						V.FLG100PCTNORMAL6UR12UM,
						V.FLGREPROGRAMADO,
						V.FLGREFINANCIADO,
						V.EDAD,
						v.edadmeses,
						V.FLGMOROSIDADEFEMAY60DIAS12UM,
						V.FLGHASTACPP4_12UR24UM,
						V.FLGCALIFDIF100PCTNORMAL3UM,
						V.OB3FGH,
						V.FLGPROVINCIAIQUITOS,
						V.FLGDEUDAREESTRUCTURADA12UM,
						V.FLGDEUDAREFINANCIADA12UM,
						V.FLGDEUDAJUDICIAL12UM,
						V.FLGDEUDACASTIGO6UR24UM,
						V.FLGDEUDACASTIGO24UM,
						V.BKNROVERSIONMODELO,
						V.RECNROVERSIONMODELO,
						V.BKSCORE,
						V.RECSCORE,
						V.FLGCalifDif100Normal03UM, ---
						CASE WHEN 'S' IN (V.FlgCreditoImpulsa,V.FlgDeudaImpulsaPeruRCC) THEN 'S' ELSE 'N' END FlgImpulsa,	--#@E2E22							
						--- #@LCB2 Inicio, trae nuevas variables de Meseta y Score de Cobranza.
						V.FLGRECHAZOMESETA,
						V.FLGRECHAZOSCORECOBRANZA,
						--- #@LCB2 Final
						--- #02WCA Inicio
						V.FLGDEUDACASTIGO3UR6UM,
						V.FLGCALIFMAYCPP3UR6UM,
						V.FLGCALIFDIF100PCTNORMALUR6UM,
						--- #02WCA Final
						--- #03WCA Inicio
						V.FLGDEUDAVENCIDAUM,
						--- #03WCA Final
						V_FecCorte as FECCORTE, --
						V.FECCORTERCC,
						--- #E2E15 Inicio
						V.FLGDEFDUDPER24UM,
						V.Rechazo_RECORDCREDITICIO12UM,
						--- #E2E15 Final
						--- #E2E04 Inicio
						'0' AS FLG_RECAL_SEG, --Aleatorio 0, 1
						'0' AS FLG_RECAL_ING,  --Aleatorio 0, 1
						R.CodGrupoEFN AS GRUPOEFECTINEGOCIO,--#E2E19  
						R.CodClienteEFN			,			--#E2E19 
						R.FlgProSinAtencion		,			--#E2E19 
						R.TipoProceso			,			--#E2E19
						R.FlgRescateANegativo	,			--#E2E23
						V.NROREPORTANTENOREGULADA,			--#E2E23
						V.CANTDOCMOROSOS		,			--#E2E23
						V.NROMESESREPORTADOSSF18UM, 		--#E2E23
						V.NROMESESREPORTADOSSF24UM, 		--#E2E23
						V.FLGNROREPORTE18UM_VP2OK, 			--#E2E23
						V.FLGINDEARRENDADO_OK	, 			--#E2E23
						V.FLGNROREPORTE24UM_RECSCORE557,	--#E2E23							
						V.CODREGLATOXICO		, 			--#E2E23
						V.CODARRENDADO			, 			--#E2E23
						V.CodFamiliar			,			--#E2E23
						V.CodIndeArrendado		,			--#E2E23
						V.DEUDATOTALSICOM		,			--#E2E24
						V.NROENTIDADESSICOM		,			--#E2E24	
						V.ANTIGUEDADVEHICULAR	,			--#E2E24
						V.CNTINMUEBLES			,			--#MLA26
						V.CODZONACOBRANZA		,			--#MLA26
						R.FLGSCOREEQUIFAX		,								
						R.RECEFECTIVOFECCORTE	,
						R.RECEFECTIVOKEYBD		,
						R.BKEFECTIVOFECCORTE	,
						R.BKEFECTIVOKEYBD		,
						R.RECELECTROFECCORTE	,
						R.RECELECTROKEYBD		,
						R.BKELECTROFECCORTE		,
						R.BKELECTROKEYBD		,
						R.RECMOTOSFECCORTE		,
						R.RECMOTOSKEYBD			,
						R.BKMOTOSFECCORTE		,
						R.BKMOTOSKEYBD			,
						R.BKMICROFECCORTE		,
						R.BKMICROKEYBD			,
						FLGPCTCALIFCPPMAYOR20	,
						FLGTIENETDCULTRCC		,
						GB.NROORDEN AS GRUPOB	, -- #E2E04 Final
						V.CODVERSIONBKELECTRO			,	--#@MLA27
						V.CODVERSIONBKMOTOS				,	--#@MLA27
						V.CODVERSIONBKEFECTIVO			,	--#@MLA27
						V.CODVERSIONBKHIPOTECARIO		,	--#@MLA27
						V.CODVERSIONBKEFECTINEGOCIO		,	--#@MLA27
						V.CODVERSIONBKCONVENIO			,	--#@MLA27
						V.CODVERSIONRECELECTRO			,	--#@MLA27
						V.CODVERSIONRECMOTOS			,	--#@MLA27
						V.CODVERSIONRECEFECTIVO			,	--#@MLA27
						V.CODVERSIONRECHIPOTECARIO		,	--#@MLA27
						V.CODVERSIONRECEFECTINEGOCIO	,	--#@MLA27
						V.CODVERSIONRECCONVENIO			,	--#@MLA27								
						V.RECSCOREELECTRO	, --#@MLA27
						V.RECSCOREMOTOS		, --#@MLA27
						V.RECSCOREEFECTIVO	, --#@MLA27
						V.BKSCOREELECTRO	, --#@MLA27 
						V.BKSCOREMOTOS		, --#@MLA27
						V.BKSCOREEFECTIVO	, --#@MLA27
						V.SCOREMICRO,		  --#@MLA27
						V.FLGREPORTADOGRUPOESPECIAL, --#@CSR28
						R.CODTIPOPROCESOEFECTIVO   , --#@E2E28
						R.CODTIPOSUBPROCESOEFECTIVO,  --#@E2E28
						V.FlgRechazoRatioUsoTdc, --#@E2E29
						V.FlgBkScoreRP3, --#@E2E29
						V.FlgRechazoScoreCobranzaMotosEfecti, --#@E2E29
						V.FlgReproVigenteMenos6UM,--#@E2E29
						V.FlgRechazoEdad	,	--#@E2E29
						V.FlgDeudaActualEFE, --#@E2E29
						V.FlgReglaRiesgoso, --#@E2E29
						V.FlgConDeudaMedianaEMP_UM, --#@E2E29
						V.FLGCLIENTEALTORIESGO --#@E2E29
					FROM DBO.TmpV_ReglasDuras_ 			V	--#WCA16
						LEFT JOIN	DBO.TMP_DETALLEBASEMASIVASAPROB C ON	C.NROORDEN = V.NROORDEN
						LEFT JOIN	DBO.Tempo_EFECTIVO_G5					D	on (D.NROORDEN = V.NROORDEN)	-- #01WCA Inicial	
						LEFT JOIN	DBO.Tempo_EFECTIVO_G7					E	on (E.NROORDEN = V.NROORDEN)	-- #01WCA Final	
						LEFT JOIN 	DBO.TMP_DetalleBaseMasivaTC				TM	on (TM.NROORDEN=V.NROORDEN)-- #E2E18
						LEFT JOIN	DBO.Tempo_TC_G5							TA	on (TA.NROORDEN = V.NROORDEN)-- #E2E18
						LEFT JOIN	DBO.Tempo_TC_G7							TB	on (TB.NROORDEN = V.NROORDEN)-- #E2E18
						LEFT JOIN	DBO.Cur_Reperfilado						R	on (R.NROORDEN = V.NROORDEN) --E2E04
						left join 	DBO.tmp_GrupoB							GB	on (GB.NROORDEN = V.NROORDEN) 
					WHERE V.FECCORTERCC = V_FecCorteRCC and V.FECCORTE=V_FecCorte AND V.FlgTipoClienteEFE in ('BK','REC')) B;
	  		V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then			
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			  
			end if;
		end if;		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 9.- Crea temporal de Interfaz 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 9;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
	 		Drop Table DBO.TMP_UMD_FED_INTERFAZTXT If exists;
			CREATE Temp table DBO.TMP_UMD_FED_INTERFAZTXT as 	
			SELECT	A.NROORDEN, A.COD_TIPODOCUMENTO, A.NRO_DOCUMENTO,
					--#E2E04 Inicio
					CASE WHEN A.GRUPOEFECTIVO = 'G99' 	AND A.FLGTIPOCLIENTEEFE = 2	AND MAX(A.DES_FILTROGENERAL) = '' AND MAX(A.DES_FILTROEFECTIVO) = ''  THEN 'G8' --#WCA09
						 WHEN A.GRUPOEFECTIVO = 'G99' 	AND A.FLGTIPOCLIENTEEFE = 1	AND MAX(A.DES_FILTROGENERAL) = '' AND MAX(A.DES_FILTROEFECTIVO) = ''  THEN 'G9' --#WCA09
						 WHEN a.GRUPOEFECTIVO = 'G0'    AND MAX(A.DES_FILTROEFECTIVO) LIKE '%obsRech27%'					  THEN 'G8'						 
						 WHEN A.GRUPOEFECTIVO = 'G5'	AND (MAX(A.DES_FILTROGENERAL)  LIKE '%obsRech28%'	OR 
						 									 MAX(A.DES_FILTROEFECTIVO) LIKE '%obsRech55%')					  THEN 'G99'									
						 WHEN A.GRUPOEFECTIVO = 'G7'	AND (MAX(A.DES_FILTROEFECTIVO) LIKE '%obsRech55%'	OR 
						 									 MAX(A.DES_FILTROEFECTIVO) LIKE '%obsRech60%')					  THEN 'G99'
						 ELSE A.GRUPOEFECTIVO 
					END COD_GRUPOEFECTIVO,	
					--#E2E04 Final
					CASE WHEN A.GRUPOTC = 'G5'		AND (MAX(A.DES_FILTROGENERAL)  LIKE '%obsRech28%'	OR 
						 								 MAX(A.DES_FILTROTARJETACREDITO) LIKE '%obsRech55%')					  THEN 'G99'									
						 WHEN A.GRUPOTC = 'G7'		AND (MAX(A.DES_FILTROTARJETACREDITO) LIKE '%obsRech55%'	OR 
						 								 MAX(A.DES_FILTROTARJETACREDITO) LIKE '%obsRech60%' OR 
						 								 MAX(A.DES_FILTROTARJETACREDITO) LIKE '%obsRech28%')					  THEN 'G99'
						 ELSE A.GRUPOTC
					END COD_GRUPOTC,	
					MAX(A.DES_FILTROGENERAL) 	DES_FILTROGENERAL,
					MAX(A.DES_FILTROELECTRO) 	DES_FILTROELECTRO,					
					MAX(A.DES_FILTROMOTOS) 	 	DES_FILTROMOTOS,
					MAX(A.DES_FILTROEFECTIVO) 	DES_FILTROEFECTIVO,					
								
					
					A.FLGTIPOCLIENTEEFE COD_TIPOCLIENTE,
					CASE WHEN A.BANCA_ELECTRO		   	= 'VP1' THEN 'VIP1' 	WHEN A.BANCA_ELECTRO		= 'VP2' 	THEN 'VIP2' 	WHEN A.BANCA_ELECTRO		= 'RECH' THEN '' 	ELSE A.BANCA_ELECTRO	  	 END BANCA_ELECTRO,
					CASE WHEN A.BANCA_MOTOS			   	= 'VP1' THEN 'VIP1' 	WHEN A.BANCA_MOTOS			= 'VP2' 	THEN 'VIP2' 	WHEN A.BANCA_MOTOS			= 'RECH' THEN '' 	ELSE A.BANCA_MOTOS		  	 END BANCA_MOTOS,
					CASE WHEN A.BANCA_EFECTIVO		   	= 'VP1' THEN 'VIP1' 	WHEN A.BANCA_EFECTIVO		= 'VP2' 	THEN 'VIP2' 	WHEN A.BANCA_EFECTIVO		= 'RECH' THEN '' 	ELSE A.BANCA_EFECTIVO	  	 END BANCA_EFECTIVO,
					--#E2E04 Inicio
					A.BANCA_HIPOTECARIO,
					CASE WHEN A.BANCA_TC		   		= 'VP1' THEN 'VIP1' 	WHEN A.BANCA_TC				= 'VP2' 	THEN 'VIP2' 	WHEN A.BANCA_TC		   	 	= 'RECH' THEN '' 	ELSE A.BANCA_TC				 END BANCA_TC,  -- TC
					CASE WHEN A.BANCA_EFECTINEGOCIO 	= 'ELT' THEN 'ELT' 		WHEN A.BANCA_EFECTINEGOCIO	= 'PRF' 	THEN 'PRF' 		WHEN A.BANCA_EFECTINEGOCIO 	= 'RECH' THEN '' 	ELSE A.BANCA_EFECTINEGOCIO	 END BANCA_EFECTINEGOCIO, -- EFECTINEGOCIO
					CASE WHEN A.BANCA_CONVENIO			= 'VP1' THEN 'VIP1'   	WHEN A.BANCA_CONVENIO		= 'VP2' 	THEN 'VIP2' 	WHEN A.BANCA_CONVENIO	    = 'RECH' THEN ''  	ELSE A.BANCA_CONVENIO		 END BANCA_CONVENIO,   -- CONVENIO
					--#E2E04 Final			
										
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECELECTRO			= 7 THEN '' ELSE CAST(A.RECELECTRO AS VARCHAR(5))			END RECELECTRO,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECMOTOS				= 7 THEN '' ELSE CAST(A.RECMOTOS AS VARCHAR(5))				END RECMOTOS,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECEFECTIVO			= 7 THEN '' ELSE CAST(A.RECEFECTIVO AS VARCHAR(5))			END RECEFECTIVO,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECTARJETA			='' THEN '' ELSE A.RECTARJETA								END RECTARJETA,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECMICRO				= 7 THEN '' ELSE CAST(A.RECMICRO AS VARCHAR(5))				END RECMICRO,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECCONVENIO			= 7 THEN '' ELSE CAST(A.RECCONVENIO AS VARCHAR(5))			END RECCONVENIO,
													
					'' COD_GRUPOELECTRO, 
					'' COD_GRUPOMOTOS,
					
					0 IMP_FASTTRACKELECTRO,
					0 IMP_FASTTRACKMOTOS,
					0 IMP_FASTTRACKEFECTIVO,
					0 IND_ACTUALIZARDATOS,
					NULL COD_PILOTOELECTRO,
					NULL COD_PILOTOMOTOS,
					NULL COD_PILOTOEFECTIVO,  
			--		A.CODVERSIONBKELECTRO   COD_VERSIONBKELECTRO,
			--		A.CODVERSIONRECELECTRO COD_VERSIONRECELECTRO,							
					------
			--		A.BKSCORE  VAL_SCOREBKELECTRO,		
			--		A.RECSCORE VAL_SCORERECELECTRO,	
			
					A.BKSCOREELECTRO  VAL_SCOREBKELECTRO,		
					A.RECSCOREELECTRO VAL_SCORERECELECTRO,	
					------
					A.FECCORTE,
					A.FECCORTERCC,
					now() as FEC_PROCESO,
					
					--- #E2E04 Inicio
					--'' DES_FILTROHIPOTECARIO,
					MAX(A.DES_FILTROHIPOTECARIO)	DES_FILTROHIPOTECARIO, --#E2E15 
					MAX(A.DES_FILTROCONVENIO)  		DES_FILTROCONVENIO,
					MAX(A.DES_FILTROTARJETACREDITO)	DES_FILTROTARJETACREDITO,
					MAX(A.DES_FILTROEFECTINEGOCIO) 	DES_FILTROEFECTINEGOCIO,				
					
					--#@MLA27 Inicio
								CASE WHEN  a.BANCA_ELECTRO		= 'RECH' THEN '0'  ELSE CAST (A.CODVERSIONBKELECTRO		 	AS VARCHAR(10))	END COD_VERSIONBKELECTRO,
					CASE WHEN  a.BANCA_MOTOS		= 'RECH' THEN '0'  ELSE CAST (A.CODVERSIONBKMOTOS		 	AS VARCHAR(10))	END COD_VERSIONBKMOTOS,
					CASE WHEN  a.BANCA_EFECTIVO		= 'RECH' THEN '0'  ELSE CAST (A.CODVERSIONBKEFECTIVO 	 	AS VARCHAR(10))	END COD_VERSIONBKEFECTIVO,
					CASE WHEN  a.BANCA_TC			= 'RECH' THEN '0'  ELSE CAST (A.CODVERSIONBKELECTRO 	 	AS VARCHAR(10))	END COD_VERSIONBKTC,
			--		A.BKNROVERSIONMODELO AS COD_VERSIONBKTC,
					CASE WHEN  a.BANCA_EFECTINEGOCIO= 'RECH' THEN '0'  ELSE CAST (A.CODVERSIONBKEFECTINEGOCIO 	AS VARCHAR(10))	END COD_VERSIONBKEFECTINEGOCIO, -- EFECTINEGOCIO
			--		A.BKNROVERSIONMODELO AS COD_VERSIONBKEFECTINEGOCIO,
					CASE WHEN  a.BANCA_CONVENIO	    = 'RECH' THEN '0'  ELSE CAST (A.CODVERSIONBKCONVENIO 	 	AS VARCHAR(10))	END COD_VERSIONBKCONVENIO ,  	-- CONVENIO
			--		A.BKNROVERSIONMODELO AS COD_VERSIONBKCONVENIO,
					A.CODVERSIONBKHIPOTECARIO   as COD_VERSIONBKHIPOTECARIO ,
			--		A.BKNROVERSIONMODELO AS COD_VERSIONBKHIPOTECARIO,	
					
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECELECTRO			= 7 THEN '0' ELSE CAST(A.CODVERSIONRECELECTRO AS VARCHAR(10))		END COD_VERSIONRECELECTRO,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECMOTOS				= 7 THEN '0' ELSE CAST(A.CODVERSIONRECMOTOS AS VARCHAR(10))			END COD_VERSIONRECMOTOS,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECEFECTIVO			= 7 THEN '0' ELSE CAST(A.CODVERSIONRECEFECTIVO AS VARCHAR(10))		END COD_VERSIONRECEFECTIVO,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECTARJETA			='' THEN '0' ELSE CAST(A.CODVERSIONRECELECTRO AS VARCHAR(10))		END COD_VERSIONRECTC,
			--		A.RECNROVERSIONMODELO AS COD_VERSIONRECTC,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECMICRO				= 7 THEN '0' ELSE CAST(A.CODVERSIONRECEFECTINEGOCIO AS VARCHAR(10))	END COD_VERSIONRECEFECTINEGOCIO,
			--		A.RECNROVERSIONMODELO AS COD_VERSIONRECEFECTINEGOCIO,
					CASE WHEN A.FLGTIPOCLIENTEEFE = 1 OR A.RECCONVENIO			= 7 THEN '0' ELSE CAST(A.CODVERSIONRECCONVENIO AS VARCHAR(10))		END COD_VERSIONRECCONVENIO,
			--		A.RECNROVERSIONMODELO AS COD_VERSIONRECCONVENIO,
					A.CODVERSIONRECHIPOTECARIO	as COD_VERSIONRECHIPOTECARIO, --#@MLA27 FINAL 
			--		A.RECNROVERSIONMODELO AS COD_VERSIONRECHIPOTECARIO,	 
					
	--				A.BKSCORE  as VAL_SCOREBKMOTOS ,A.BKSCORE  as VAL_SCOREBKEFECTIVO ,A.BKSCORE  as VAL_SCOREBKHIPOTECARIO ,A.BKSCORE  as VAL_SCOREBKTC ,A.BKSCORE  as VAL_SCOREBKEFECTINEGOCIO ,A.BKSCORE  as VAL_SCOREBKCONVENIO , --#WCA06
	--				A.RECSCORE as VAL_SCORERECMOTOS,A.RECSCORE as VAL_SCORERECEFECTIVO,A.RECSCORE as VAL_SCORERECHIPOTECARIO,A.RECSCORE as VAL_SCORERECTC,A.RECSCORE as VAL_SCORERECEFECTINEGOCIO,A.RECSCORE as VAL_SCORERECCONVENIO, --#WCA06
					A.BKSCOREMOTOS  as VAL_SCOREBKMOTOS ,A.BKSCOREEFECTIVO  as VAL_SCOREBKEFECTIVO ,A.BKSCOREELECTRO  as VAL_SCOREBKHIPOTECARIO ,A.BKSCOREELECTRO  as VAL_SCOREBKTC ,A.SCOREMICRO  as VAL_SCOREBKEFECTINEGOCIO ,A.BKSCOREELECTRO  as VAL_SCOREBKCONVENIO , --#WCA06
					A.RECSCOREMOTOS as VAL_SCORERECMOTOS,A.RECSCOREEFECTIVO as VAL_SCORERECEFECTIVO,A.RECSCOREELECTRO as VAL_SCORERECHIPOTECARIO,A.RECSCOREELECTRO as VAL_SCORERECTC,A.SCOREMICRO  as VAL_SCORERECEFECTINEGOCIO,A.RECSCOREELECTRO as VAL_SCORERECCONVENIO, --#WCA06
					---- 
					A.FLG_RECAL_SEG,
					A.FLG_RECAL_ING,					
					A.RECEFECTIVOFECCORTE,
					A.RECEFECTIVOKEYBD,
					A.BKEFECTIVOFECCORTE,
					A.BKEFECTIVOKEYBD,
					A.RECELECTROFECCORTE,
					A.RECELECTROKEYBD,
					A.BKELECTROFECCORTE,
					A.BKELECTROKEYBD,
					A.RECMOTOSFECCORTE,
					A.RECMOTOSKEYBD,
					A.BKMOTOSFECCORTE,
					A.BKMOTOSKEYBD,
					A.BKMICROFECCORTE,
					A.BKMICROKEYBD	,				
					--- #E2E04 Final
					a.GRUPOEFECTINEGOCIO,	--#E2E19  
					a.CodClienteEFN		,	--#E2E19
					a.TipoProceso		,	--#E2E19
					a.CODTIPOPROCESOEFECTIVO, 	--#@E2E28
					a.CODTIPOSUBPROCESOEFECTIVO --#@E2E28

					
			FROM	(
					SELECT	A.NROORDEN,
							A.CODTIPODOCUMENTO as COD_TIPODOCUMENTO,
							A.NUMDOCUMENTO as NRO_DOCUMENTO,
							A.COD_SEGTORIESGO,
							CASE WHEN A.COD_SEGTORIESGO  = 'FLG_GENERAL'																														THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROGENERAL,
							CASE WHEN (A.COD_SEGTORIESGO = 'FLG_ELECTROBK'			AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO = 'FLG_ELECTROREC'  		AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROELECTRO,
							CASE WHEN (A.COD_SEGTORIESGO = 'FLG_MOTOSBK'			AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO = 'FLG_MOTOSREC'	   		AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROMOTOS,
							CASE WHEN (A.COD_SEGTORIESGO = 'FLG_EFECTIVOBK'			AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO = 'FLG_EFECTIVOREC' 		AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROEFECTIVO,
							--#E2E04 Inicio
							CASE WHEN (A.COD_SEGTORIESGO = 'FLG_TARJETABK'		 	AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO ='FLG_TARJETAREC'  		AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROTARJETACREDITO,
							
							CASE WHEN (A.COD_SEGTORIESGO IN ('FLG_CINTERNOBK',
															 'FLG_CEPUBLICOBK',
															 'FLG_CEPRIVADOBK',
															 'FLG_TARJETACOL') 	AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO IN ('FLG_CINTERNOBK',
																													 					   'FLG_CEPUBLICOBK',
															 														 					   'FLG_CEPRIVADOBK',
																																		   'FLG_TARJETACOL') 	AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROCONVENIO,						
							CASE WHEN (A.COD_SEGTORIESGO = 'FLG_EFECTINEGOCIOBK'	AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO ='FLG_EFECTINEGOCIOBK'	AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROEFECTINEGOCIO,
							--#E2E04 Final
							
							--#E2E15 Inicio
							CASE WHEN (A.COD_SEGTORIESGO = 'FLG_HIPOTECBK'			AND A.FLGTIPOCLIENTEEFE = 1) OR (A.COD_SEGTORIESGO = 'FLG_HIPOTECREC' 		AND A.FLGTIPOCLIENTEEFE = 2)	THEN (CASE WHEN A.DES_FILTROREGLA <> '' THEN SUBSTR(A.DES_FILTROREGLA, 2, LENGTH(A.DES_FILTROREGLA)) ELSE A.DES_FILTROREGLA END) ELSE '' END AS DES_FILTROHIPOTECARIO,
							--#E2E15 Final
							
							A.FLGTIPOCLIENTEEFE,
							A.BANCA_ELECTRO,
							A.BANCA_MOTOS,
							A.BANCA_EFECTIVO,						
							--- #E2E04 Inicio
							A.BANCA_HIPOTECARIO,
							A.BANCA_TC, --TC
							A.BANCA_EFECTINEGOCIO, --EFECTINEGOCIO
							A.BANCA_CONVENIO, 		--CONVENIO
							--- #E2E04 Final
							A.RECELECTRO,
							A.RECMOTOS,
							A.RECEFECTIVO,
							--- #E2E04 Inicio
							A.RECTARJETA,
							A.RECMICRO,
							A.RECCONVENIO,
							--- #E2E04 Final									
							--A.APRRECEFECTIVA , -------
							--A.APRBKEFECTIVA, ---------
							A.GRUPOEFECTIVO,							
							A.BKNROVERSIONMODELO,
							A.RECNROVERSIONMODELO,
							
							A.CODVERSIONBKELECTRO  ,
							A.CODVERSIONRECELECTRO ,							
					
							A.CODVERSIONBKMOTOS				,	--#@MLA27
							A.CODVERSIONBKEFECTIVO			,	--#@MLA27
							A.CODVERSIONBKHIPOTECARIO		,	--#@MLA27
							A.CODVERSIONBKEFECTINEGOCIO		,	--#@MLA27
							A.CODVERSIONBKCONVENIO			,	--#@MLA27
						
							A.CODVERSIONRECMOTOS			,	--#@MLA27
							A.CODVERSIONRECEFECTIVO			,	--#@MLA27
							A.CODVERSIONRECHIPOTECARIO		,	--#@MLA27
							A.CODVERSIONRECEFECTINEGOCIO	,	--#@MLA27
							A.CODVERSIONRECCONVENIO			,	--#@MLA27								
							A.BKSCORE,
							A.RECSCORE,							
							A.RECSCOREELECTRO				, --#@MLA27
							A.RECSCOREMOTOS					, --#@MLA27
							A.RECSCOREEFECTIVO				, --#@MLA27
							A.BKSCOREELECTRO				, --#@MLA27
							A.BKSCOREMOTOS					, --#@MLA27
							A.BKSCOREEFECTIVO				, --#@MLA27
							A.SCOREMICRO					, --#@MLA27							
							A.FECCORTE,
							A.FECCORTERCC,
							--- #E2E04 Inicio
							A.FLG_RECAL_SEG,
							A.FLG_RECAL_ING,
							
							A.RECEFECTIVOFECCORTE	,
							A.RECEFECTIVOKEYBD		,
							A.BKEFECTIVOFECCORTE	,
							A.BKEFECTIVOKEYBD		,
							A.RECELECTROFECCORTE	,
							A.RECELECTROKEYBD		,
							A.BKELECTROFECCORTE		,
							A.BKELECTROKEYBD		,
							A.RECMOTOSFECCORTE		,
							A.RECMOTOSKEYBD			,
							A.BKMOTOSFECCORTE		,
							A.BKMOTOSKEYBD			,
							A.BKMICROFECCORTE		,
							A.BKMICROKEYBD			,
							A.grupotc				,
							a.GRUPOEFECTINEGOCIO	,	--#E2E19  
							a.CodClienteEFN			,	--#E2E19
							a.TipoProceso			,	--#E2E19 	
							a.CODTIPOPROCESOEFECTIVO 		,	--#@E2E28
							a.CODTIPOSUBPROCESOEFECTIVO 		--#@E2E28							
							--- #E2E04 Final
					FROM	DBO.FED_TMP_RECHAZOS A						
					) A
		
			GROUP BY A.NROORDEN,
					A.COD_TIPODOCUMENTO,
					A.NRO_DOCUMENTO,
					A.FLGTIPOCLIENTEEFE,
					A.BANCA_ELECTRO,
					A.BANCA_MOTOS,
					A.BANCA_EFECTIVO,				
					--- #E2E04 Inicio
					A.BANCA_HIPOTECARIO,
					A.BANCA_TC, --TC
					A.BANCA_EFECTINEGOCIO, --EFECTINEGOCIO
					A.BANCA_CONVENIO, 		--CONVENIO
					--- #E2E04 Inicio
					A.RECELECTRO,
					A.RECMOTOS,
					A.RECEFECTIVO,
					A.RECTARJETA,
					A.RECMICRO,
					A.RECCONVENIO,				
					--
					A.GRUPOEFECTIVO,
					a.BKSCORE,
					a.RECSCORE,
					--
					A.CODVERSIONBKELECTRO		,	--#@MLA27
					A.CODVERSIONRECELECTRO		,	--#@MLA27
					
					COD_VERSIONBKELECTRO,
					COD_VERSIONRECELECTRO,		
					
					COD_VERSIONBKMOTOS			,	--#@MLA27
					COD_VERSIONBKEFECTIVO		,	--#@MLA27
					COD_VERSIONBKHIPOTECARIO	,	--#@MLA27
					COD_VERSIONBKEFECTINEGOCIO	,	--#@MLA27
					COD_VERSIONBKCONVENIO		,	--#@MLA27
				
					COD_VERSIONRECMOTOS			,	--#@MLA27
					COD_VERSIONRECEFECTIVO		,	--#@MLA27
					COD_VERSIONRECHIPOTECARIO	,	--#@MLA27
					COD_VERSIONRECEFECTINEGOCIO	,	--#@MLA27
					COD_VERSIONRECCONVENIO		,	--#@MLA27	
					
					a.RECSCOREELECTRO	, --#@MLA27
					a.RECSCOREMOTOS		, --#@MLA27
					a.RECSCOREEFECTIVO	, --#@MLA27
					a.BKSCOREELECTRO	, --#@MLA27
					a.BKSCOREMOTOS		, --#@MLA27
					a.BKSCOREEFECTIVO	, --#@MLA27
					a.SCOREMICRO		, --#@MLA27					
					
					A.FECCORTE,
					A.FECCORTERCC, 
					--- #E2E04 Inicio
					A.FLG_RECAL_SEG,
					A.FLG_RECAL_ING,
					
					A.RECEFECTIVOFECCORTE,
					A.RECEFECTIVOKEYBD,
					A.BKEFECTIVOFECCORTE,
					A.BKEFECTIVOKEYBD,
					A.RECELECTROFECCORTE,
					A.RECELECTROKEYBD,
					A.BKELECTROFECCORTE,
					A.BKELECTROKEYBD,
					A.RECMOTOSFECCORTE,
					A.RECMOTOSKEYBD,
					A.BKMOTOSFECCORTE,
					A.BKMOTOSKEYBD,
					A.BKMICROFECCORTE,
					A.BKMICROKEYBD,
					A.grupotc,
					a.GRUPOEFECTINEGOCIO,	--#E2E19  
					a.CodClienteEFN,	--#E2E19
					a.TipoProceso ,		--#E2E19
					a.CODTIPOPROCESOEFECTIVO 	,	--#@E2E28
					a.CODTIPOSUBPROCESOEFECTIVO 	--#@E2E28
					;--- #E2E04 Final 
	  		V_NroRegistros  := ROW_COUNT;
			
			If V_ejecutaLog = 1 Then		  	
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');	
			end if;
		end if;		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 10.- Poblado de Interfaz FED 
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 10;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Delete from DBO.UMD_FED_INTERFAZTXT Where Fec_CorteEFE = V_FecCorte and Fec_CorteRCC=V_FecCorteRCC;		 
			INSERT INTO DBO.UMD_FED_INTERFAZTXT(	--#WCA05
			FEC_CORTEEFE,FEC_CORTERCC, NROORDEN, COD_TIPODOCUMENTO, COD_NUMDOCUMENTO,
			DES_FILTROGENERAL,DES_FILTROELECTRO,DES_FILTROMOTOS,DES_FILTROEFECTIVO,DES_FILTROHIPOTECARIO,DES_FILTROCONVENIO,DES_FILTROTARJETACREDITO,DES_FILTROEFECTINEGOCIO,
			COD_TIPOCLIENTE,COD_BKELECTRO,COD_BKMOTOS,COD_BKEFECTIVO,COD_BKHIPOTECARIO,COD_BKTARJETACREDITO,COD_BKEFECTINEGOCIO,COD_BKCONVENIO,
			COD_RECELECTRO, COD_RECMOTOS,COD_RECEFECTIVO,COD_RECTARJETACREDITO,COD_RECCONVENIO,
			
			COD_GRUPOEFECTIVO,COD_GRUPOELECTRO,COD_GRUPOMOTOS,			
			IMP_FASTTRACKELECTRO,IMP_FASTTRACKMOTOS,IMP_FASTTRACKEFECTIVO,IND_ACTUALIZARDATOS,COD_PILOTOELECTRO,COD_PILOTOMOTOS,COD_PILOTOEFECTIVO,
			
			COD_VERSIONBKLECTRO,COD_VERSIONBKMOTOS,COD_VERSIONBKEFECTIVO,COD_VERSIONBKHIPOTECARIO, COD_VERSIONBKTARJETACREDITO,COD_VERSIONBKEFECTINEGOCIO,COD_VERSIONBKCONVENIO,			
			COD_VERSIONRECELECTRO,COD_VERSIONRECMOTOS,COD_VERSIONRECEFECTIVO,COD_VERSIONRECHIPOTECARIO, COD_VERSIONRECTARJETACREDITO,COD_VERSIONRECCONVENIO,
			
			VAL_SCOREBKELECTRO,VAL_SCOREBKMOTOS,VAL_SCOREBKEFECTIVO,VAL_SCOREBKHIPOTECARIO, VAL_SCOREBKTARJETACREDITO,VAL_SCOREBKEFECTINEGOCIO,VAL_SCOREBKCONVENIO,VAL_SCORERECELECTRO,
			VAL_SCORERECMOTOS,VAL_SCORERECEFECTIVO,VAL_SCORERECHIPOTECARIO, VAL_SCORERECTARJETACREDITO,VAL_SCORERECCONVENIO,
			
			DES_SEGMENTOMODELO,DES_GRUPOBASE,DES_VERSIONMODELO,DES_SCOREMODELO,
			
			FLG_RECAL_SEG,FLG_RECAL_ING,
			
			RECEFECTIVOFECCORTE, RECEFECTIVOKEYBD, BKEFECTIVOFECCORTE, BKEFECTIVOKEYBD, RECELECTROFECCORTE, RECELECTROKEYBD, BKELECTROFECCORTE, BKELECTROKEYBD,
			RECMOTOSFECCORTE,RECMOTOSKEYBD, BKMOTOSFECCORTE, BKMOTOSKEYBD, BKMICROFECCORTE, BKMICROKEYBD, FEC_PROCESO, 
			CODTIPOCLIENTE_EFECTINEGOCIO,TIPOPROCESO, --#E2E19		
			FlgCalificacionTodoNormal6UM,--#@COSR25
			TIPOPROCESOEFECTIVO, TIPOSUBPROCESOEFECTIVO, --#@E2E28
			NROEJECUCION ) 

			select 
			a.FECCORTE,a.FECCORTERCC, a.NROORDEN,a.COD_TIPODOCUMENTO,a.NRO_DOCUMENTO,			
			a.DES_FILTROGENERAL,a.DES_FILTROELECTRO,a.DES_FILTROMOTOS,a.DES_FILTROEFECTIVO,a.DES_FILTROHIPOTECARIO, a.DES_FILTROCONVENIO,a.DES_FILTROTARJETACREDITO,a.DES_FILTROEFECTINEGOCIO,				
			a.COD_TIPOCLIENTE,a.BANCA_ELECTRO,a.BANCA_MOTOS,a.BANCA_EFECTIVO, '' BANCA_HIPOTECARIO,a.BANCA_TC,a.BANCA_EFECTINEGOCIO,a.BANCA_CONVENIO,			
			a.RECELECTRO,a.RECMOTOS,a.RECEFECTIVO, a.RECTARJETA,a.RECCONVENIO,	
			
			a.COD_GRUPOEFECTIVO,
			
			a.COD_GRUPOELECTRO,				
			'' COD_GRUPOMOTOS,			
			
			a.IMP_FASTTRACKELECTRO,a.IMP_FASTTRACKMOTOS,a.IMP_FASTTRACKEFECTIVO,a.IND_ACTUALIZARDATOS,a.COD_PILOTOELECTRO,a.COD_PILOTOMOTOS,a.COD_PILOTOEFECTIVO,
			
			a.COD_VERSIONBKELECTRO,a.COD_VERSIONBKMOTOS,a.COD_VERSIONBKEFECTIVO,a.COD_VERSIONBKHIPOTECARIO,a.COD_VERSIONBKTC,a.COD_VERSIONBKEFECTINEGOCIO,a.COD_VERSIONBKCONVENIO,			
			a.COD_VERSIONRECELECTRO,a.COD_VERSIONRECMOTOS,a.COD_VERSIONRECEFECTIVO,a.COD_VERSIONRECHIPOTECARIO,a.COD_VERSIONRECTC,a.COD_VERSIONRECCONVENIO,				
			
			a.VAL_SCOREBKELECTRO,a.VAL_SCOREBKMOTOS,a.VAL_SCOREBKEFECTIVO,a.VAL_SCOREBKHIPOTECARIO,a.VAL_SCOREBKTC,a.VAL_SCOREBKEFECTINEGOCIO,a.VAL_SCOREBKCONVENIO,
			a.VAL_SCORERECELECTRO,a.VAL_SCORERECMOTOS,a.VAL_SCORERECEFECTIVO,a.VAL_SCORERECHIPOTECARIO,a.VAL_SCORERECTC,a.VAL_SCORERECCONVENIO,			
			
			---- Nuevo Modelo solicitado
			CASE WHEN a.COD_TIPOCLIENTE = 1
				 THEN A.BANCA_ELECTRO || ';' || A.BANCA_MOTOS || ';' || A.BANCA_EFECTIVO || ';' || A.BANCA_HIPOTECARIO 	|| ';' ||  A.BANCA_TC   || ';' || A.BANCA_EFECTINEGOCIO || ';' || A.BANCA_CONVENIO
     		   --ELSE A.RECELECTRO	  || ';' ||	A.RECMOTOS	  || ';' || A.RECEFECTIVO    || ';' || '' 					|| ';' ||  A.RECTARJETA || ';' || '' 				 	|| ';' || A.RECCONVENIO #WCA07
				 ELSE A.RECELECTRO	  || ';' ||	A.RECMOTOS	  || ';' || A.RECEFECTIVO    || ';' || '' 					|| ';' ||  A.RECTARJETA || ';' || A.BANCA_EFECTINEGOCIO || ';' || A.RECCONVENIO						 		
			END AS DES_SEGMENTOMODELO,			
						
					
		--	(COD_GRUPOELECTRO || ';' || COD_GRUPOMOTOS || ';' || COD_GRUPOEFECTIVO || ';' || COD_GRUPOTC || ';' || '' || ';' || '' || ';' || '') AS DES_GRUPOBASE,
			(COD_GRUPOELECTRO || ';' || COD_GRUPOMOTOS || ';' || COD_GRUPOEFECTIVO || ';' || '' || ';' || COD_GRUPOTC || ';' || nvl(GRUPOEFECTINEGOCIO,'4') || ';' || '') AS DES_GRUPOBASE, --#E2E19
			
			
			CASE WHEN 	a.COD_TIPOCLIENTE = 1
				 THEN 	a.COD_VERSIONBKELECTRO 	|| ';' || a.COD_VERSIONBKMOTOS 	|| ';' || a.COD_VERSIONBKEFECTIVO  || ';' || a.COD_VERSIONBKHIPOTECARIO		|| ';' || a.COD_VERSIONBKTC  || ';'  || a.COD_VERSIONBKEFECTINEGOCIO  || ';' || a.COD_VERSIONBKCONVENIO
			   	 ELSE 	a.COD_VERSIONRECELECTRO || ';' || a.COD_VERSIONRECMOTOS || ';' || a.COD_VERSIONRECEFECTIVO || ';' || a.COD_VERSIONRECHIPOTECARIO	|| ';' || a.COD_VERSIONRECTC || ';'  || a.COD_VERSIONRECEFECTINEGOCIO || ';' || a.COD_VERSIONRECCONVENIO --#WCA12
			END AS DES_VERSIONMODELO,
						
			CASE WHEN 	a.COD_TIPOCLIENTE = 1
				 THEN 	a.VAL_SCOREBKELECTRO  	|| ';' || a.VAL_SCOREBKMOTOS  	|| ';' || a.VAL_SCOREBKEFECTIVO   || ';' || a.VAL_SCOREBKHIPOTECARIO	|| ';' || a.VAL_SCOREBKTC  || ';' || a.VAL_SCOREBKEFECTINEGOCIO || ';' || a.VAL_SCOREBKCONVENIO
				 ELSE 	a.VAL_SCORERECELECTRO 	|| ';' || a.VAL_SCORERECMOTOS	|| ';' || a.VAL_SCORERECEFECTIVO  || ';' || a.VAL_SCORERECHIPOTECARIO	|| ';' || a.VAL_SCORERECTC || ';' || a.VAL_SCORERECEFECTINEGOCIO|| ';' || a.VAL_SCORERECCONVENIO	--#WCA12
     		   --ELSE 	a.VAL_SCORERECELECTRO 	|| ';' || a.VAL_SCORERECMOTOS	|| ';' || a.VAL_SCORERECEFECTIVO  || ';' || a.VAL_SCORERECHIPOTECARIO	|| ';' || a.VAL_SCORERECTC || ';' || ''                         || ';' || a.VAL_SCORERECCONVENIO
			END AS COD_SCOREMODELO,					
					
			a.FLG_RECAL_SEG,
			a.FLG_RECAL_ING,
			
			a.RECEFECTIVOFECCORTE,
			a.RECEFECTIVOKEYBD,
			a.BKEFECTIVOFECCORTE,
			a.BKEFECTIVOKEYBD,
			a.RECELECTROFECCORTE,
			a.RECELECTROKEYBD,
			a.BKELECTROFECCORTE,
			a.BKELECTROKEYBD,
			a.RECMOTOSFECCORTE,
			a.RECMOTOSKEYBD,
			a.BKMOTOSFECCORTE,
			a.BKMOTOSKEYBD,
			a.BKMICROFECCORTE,
			a.BKMICROKEYBD,
			a.FEC_PROCESO,
			nvl(a.CodClienteEFN,1)	,	--#E2E19
			
			CASE WHEN a.TipoProceso	IS NULL THEN 3
				 WHEN a.TipoProceso= 4		THEN 3	--#E2E21
				 ELSE a.TipoProceso
			END TipoProceso,			--#E2E19 -- Cambio solicitado por Giancarlo Reyes 05/08/2023				
			B.FlgCalificacionTodoNormal6UM,--#@COSR25
			a.CODTIPOPROCESOEFECTIVO, 			--#@E2E28
			a.CODTIPOSUBPROCESOEFECTIVO, 		--#@E2E28
			V_NroEjecucion AS NroEjecucion
			--- #E2E04 Final
			from DBO.TMP_UMD_FED_INTERFAZTXT a 	--#WCA05
				Left Join PROD_RCC..RCC_VariablesEspeciales B on B.NroOrden = A.NroOrden and B.CodFecCorteRCC = V_CodFecCorteRCC--#@COSR24 
				Left Join DBO.Tempo_ELECTRO_G0	 EG0 On (EG0.NroOrden = a.NroOrden)
				Left Join DBO.Tempo_ELECTRO_G1	 EG1 On (EG1.NroOrden = a.NroOrden)
				Left Join DBO.Tempo_MOTOS_G0	 MG0 On (MG0.NroOrden = a.NroOrden)
				Left Join DBO.Tempo_MOTOS_G1	 MG1 On (MG1.NroOrden = a.NroOrden)
			Where Banca_Electro is not null; 

			---	
	  		V_NroRegistros  := ROW_COUNT;
			
			If V_ejecutaLog = 1 Then		  		
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');			  
			end if;
		end if;	

		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 11.- AGREGA NBKs que estan Black List
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 11;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Insert into DBO.UMD_FED_INTERFAZTXT(
			 FEC_CORTEEFE,
			 FEC_CORTERCC,
			 NROORDEN,
			 COD_TIPODOCUMENTO,
			 COD_NUMDOCUMENTO,
			 DES_FILTROGENERAL,
			 DES_FILTROELECTRO,
			 DES_FILTROMOTOS,
			 DES_FILTROEFECTIVO,
			 DES_FILTROHIPOTECARIO,
			 DES_FILTROCONVENIO,
			 DES_FILTROTARJETACREDITO,
			 DES_FILTROEFECTINEGOCIO,
			 COD_TIPOCLIENTE,
			 COD_BKELECTRO,
			 COD_BKMOTOS,
			 COD_BKEFECTIVO,
			 COD_BKHIPOTECARIO,
			 COD_BKTARJETACREDITO,
			 COD_BKEFECTINEGOCIO,
			 COD_BKCONVENIO,
			 COD_RECELECTRO,
			 COD_RECMOTOS,
			 COD_RECEFECTIVO,
			 COD_RECTARJETACREDITO,
			 COD_RECCONVENIO,
			 COD_GRUPOEFECTIVO,
			 COD_GRUPOELECTRO,
			 COD_GRUPOMOTOS,
			 IMP_FASTTRACKELECTRO,
			 IMP_FASTTRACKMOTOS,
			 IMP_FASTTRACKEFECTIVO,
			 IND_ACTUALIZARDATOS,
			 COD_PILOTOELECTRO,
			 COD_PILOTOMOTOS,
			 COD_PILOTOEFECTIVO,
			 COD_VERSIONBKLECTRO,
			 COD_VERSIONBKMOTOS,
			 COD_VERSIONBKEFECTIVO,
			 COD_VERSIONBKHIPOTECARIO,
			 COD_VERSIONBKTARJETACREDITO,
			 COD_VERSIONBKEFECTINEGOCIO,
			 COD_VERSIONBKCONVENIO,
			 COD_VERSIONRECELECTRO,
			 COD_VERSIONRECMOTOS,
			 COD_VERSIONRECEFECTIVO,
			 COD_VERSIONRECHIPOTECARIO,
			 COD_VERSIONRECTARJETACREDITO,
			 COD_VERSIONRECCONVENIO,
			 VAL_SCOREBKELECTRO,
			 VAL_SCOREBKMOTOS,
			 VAL_SCOREBKEFECTIVO,
			 VAL_SCOREBKHIPOTECARIO,
			 VAL_SCOREBKTARJETACREDITO,
			 VAL_SCOREBKEFECTINEGOCIO,
			 VAL_SCOREBKCONVENIO,
			 VAL_SCORERECELECTRO,
			 VAL_SCORERECMOTOS,
			 VAL_SCORERECEFECTIVO,
			 VAL_SCORERECHIPOTECARIO,
			 VAL_SCORERECTARJETACREDITO,
			 VAL_SCORERECCONVENIO,
			 DES_SEGMENTOMODELO,
			 DES_GRUPOBASE,
			 DES_VERSIONMODELO,
			 DES_SCOREMODELO,
			 FLG_RECAL_SEG,
			 FLG_RECAL_ING,
			 RECEFECTIVOFECCORTE,
			 RECEFECTIVOKEYBD,
			 BKEFECTIVOFECCORTE,
			 BKEFECTIVOKEYBD,
			 RECELECTROFECCORTE,
			 RECELECTROKEYBD,
			 BKELECTROFECCORTE,
			 BKELECTROKEYBD,
			 RECMOTOSFECCORTE,
			 RECMOTOSKEYBD,
			 BKMOTOSFECCORTE,
			 BKMOTOSKEYBD,
			 BKMICROFECCORTE,
			 BKMICROKEYBD,
			 FEC_PROCESO,
			 CODTIPOCLIENTE_EFECTINEGOCIO,	--#E2E19
			 TIPOPROCESO, 					--#E2E19
			 FlgCalificacionTodoNormal6UM,--#@COSR25
			 TIPOPROCESOEFECTIVO, TIPOSUBPROCESOEFECTIVO, --#@E2E28
			 NROEJECUCION)
			select a.FECCORTE										,
				a.FECCORTERCC									, 
				a.NROORDEN										,
				a.CodTipoDocumento 	as COD_TIPODOCUMENTO		,
				a.NumDocumento 		as NRO_DOCUMENTO			,			
				''					as DES_FILTROGENERAL		,
				'obsRech199'		as DES_FILTROELECTRO		,
				'obsRech199'		as DES_FILTROMOTOS			,
				'obsRech199'||FlgEdad1||FlgEdad2	as DES_FILTROEFECTIVO	,
				''					as DES_FILTROHIPOTECARIO	, 
				''					as DES_FILTROCONVENIO		,
				'obsRech199'		as DES_FILTROTARJETACREDITO	,
				'obsRech199'		as DES_FILTROEFECTINEGOCIO	,				
				0					as COD_TIPOCLIENTE			,
				''					as BANCA_ELECTRO			,
				''					as BANCA_MOTOS				,
				''					as BANCA_EFECTIVO			, 
				''					as BANCA_HIPOTECARIO		,
				''					as BANCA_TC					,
				''					as BANCA_EFECTINEGOCIO		,
				''					as BANCA_CONVENIO			,			
				''					as RECELECTRO				,
				''					as RECMOTOS					,
				''					as RECEFECTIVO				,	 
				''					as RECTARJETA				,
				''					as RECCONVENIO				,	
				''					as COD_GRUPOEFECTIVO		,
				''					as COD_GRUPOELECTRO			,				
				''					as COD_GRUPOMOTOS			,			
				0					as IMP_FASTTRACKELECTRO		,
				0					as IMP_FASTTRACKMOTOS		,
				0					as IMP_FASTTRACKEFECTIVO	,
				0					as IND_ACTUALIZARDATOS		,		
				null 				as COD_PILOTOELECTRO		,
				null 				as COD_PILOTOMOTOS			,
				null 				as COD_PILOTOEFECTIVO		,
				0					as COD_VERSIONBKLECTRO		,
				0					as COD_VERSIONBKMOTOS		,
				0					as COD_VERSIONBKEFECTIVO	,
				0					as COD_VERSIONBKHIPOTECARIO	,
				0					as COD_VERSIONBKTC			,
				0					as COD_VERSIONBKEFECTINEGOCIO,
				0					as COD_VERSIONBKCONVENIO	,			
				0					as COD_VERSIONRECELECTRO	,
				0					as COD_VERSIONRECMOTOS		,
				0					as COD_VERSIONRECEFECTIVO	,
				0					as COD_VERSIONRECHIPOTECARIO,
				0					as COD_VERSIONRECTC			,
				0					as COD_VERSIONRECCONVENIO	,				
				0					as VAL_SCOREBKELECTRO		,
				0					as VAL_SCOREBKMOTOS			,
				0					as VAL_SCOREBKEFECTIVO		,
				0					as VAL_SCOREBKHIPOTECARIO	,
				0					as VAL_SCOREBKTC			,
				0					as VAL_SCOREBKEFECTINEGOCIO	,
				0					as VAL_SCOREBKCONVENIO		,
				0					as VAL_SCORERECELECTRO		,
				0					as VAL_SCORERECMOTOS		,
				0					as VAL_SCORERECEFECTIVO		,
				0					as VAL_SCORERECHIPOTECARIO	,
				0					as VAL_SCORERECTC			,
				0					as VAL_SCORERECCONVENIO		,			
				';;;;;;' 			as DES_SEGMENTOMODELO		,			
		--		';;;;;;' 			as DES_GRUPOBASE			,	-- Vacio indicado por Gonzalo
				('' || ';' || '' || ';' || '' || ';' || '' || ';' || '' || ';' || CodGrupoEFN || ';' || '') AS DES_GRUPOBASE,					
				'0;0;0;0;0;0;0' 	as DES_VERSIONMODELO		,
				'0;0;0;0;0;0;0' 	as COD_SCOREMODELO			,					
				0					as FLG_RECAL_SEG			,
				0					as FLG_RECAL_ING			,
				null				as RECEFECTIVOFECCORTE		,
				null				as RECEFECTIVOKEYBD			,
				null				as BKEFECTIVOFECCORTE		,
				0					as BKEFECTIVOKEYBD			,
				null				as RECELECTROFECCORTE		,
				null				as RECELECTROKEYBD			,
				null				as BKELECTROFECCORTE		,
				0					as BKELECTROKEYBD			,
				null				as RECMOTOSFECCORTE			,
				null				as RECMOTOSKEYBD			,
				null				as BKMOTOSFECCORTE			,
				0					as BKMOTOSKEYBD				,
				null				as BKMICROFECCORTE			,
				null				as BKMICROKEYBD				,
				now()				as FEC_PROCESO				,
				
				0					as CODTIPOCLIenteEFN		,	--#E2E19								
				3					as TipoProceso				,	--#E2E19
				B.FlgCalificacionTodoNormal6UM,
				'4'					as	TIPOPROCESOEFECTIVO		,	--#@E2E28
				'0@0@0@6'			as	TIPOSUBPROCESOEFECTIVO	,	--#@E2E28
				V_NroEjecucion 		as NroEjecucion
				
			from (	SELECT a.*, 
						case WHEN  nvl(a.Edad,0)<25 Then '@obsRech49' else '' end as FlgEdad1, -- #E2E20
						case WHEN (nvl(a.edad,0)=74 and nvl(a.edadmeses,0)>10) or nvl(a.Edad,0)>74 Then '@obsRech55' else '' end as FlgEdad2, -- #E2E20
						Case when a.CodZonaUbigeo='A' then '1'
						 	 when a.CodZonaUbigeo='B' then '2'
						 	 when a.CodZonaUbigeo='C' then '3'
						 	 when a.CodZonaUbigeo='D' THEN '4'
						end CodGrupoEFN								
					from PROD_MODELOS.DBO.UMD_FED_RDGENERAL_SEMANAL	a		
					where a.feccorte = V_FecCorte and a.FlgTipoClienteEFE = 'NBK' and a.FLGRECHAZADOLISTANEGRA = 'S'
				 ) A
				Left Join PROD_RCC..RCC_VariablesEspeciales B on B.NroOrden = A.NroOrden and B.CodFecCorteRCC = V_CodFecCorteRCC;--#@COSR25 

			V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso, V_CodError, V_NroRegistros,'');
			end if;
		end if;	
	-------------------------------------------------------------------------------------------------------------------------------------------------
	-- 12.- AGREGA registros de otros Tipos de Documento
	-------------------------------------------------------------------------------------------------------------------------------------------------
	-- Inicio #@COSR25 
	V_CodPaso := 12;
	if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
		Insert into DBO.UMD_FED_INTERFAZTXT(
			FEC_CORTEEFE,		FEC_CORTERCC,			NROORDEN,			COD_TIPODOCUMENTO,
			COD_NUMDOCUMENTO,	DES_FILTROGENERAL,		DES_FILTROELECTRO,	DES_FILTROMOTOS,
			DES_FILTROEFECTIVO,DES_FILTROHIPOTECARIO, 	DES_FILTROCONVENIO,	DES_FILTROTARJETACREDITO,
			DES_FILTROEFECTINEGOCIO, COD_TIPOCLIENTE,	COD_BKELECTRO,		COD_BKMOTOS,
			COD_BKEFECTIVO,		COD_BKHIPOTECARIO,		COD_BKTARJETACREDITO,COD_BKEFECTINEGOCIO,
			COD_BKCONVENIO,		COD_RECELECTRO,			COD_RECMOTOS,		COD_RECEFECTIVO,
			COD_RECTARJETACREDITO, COD_RECCONVENIO,		COD_GRUPOEFECTIVO,	COD_GRUPOELECTRO,
			COD_GRUPOMOTOS,		IMP_FASTTRACKELECTRO,	IMP_FASTTRACKMOTOS,	IMP_FASTTRACKEFECTIVO,
			IND_ACTUALIZARDATOS,COD_PILOTOELECTRO,		COD_PILOTOMOTOS,	COD_PILOTOEFECTIVO,
			COD_VERSIONBKLECTRO,COD_VERSIONBKMOTOS,		COD_VERSIONBKEFECTIVO,COD_VERSIONBKHIPOTECARIO,
			COD_VERSIONBKTARJETACREDITO,COD_VERSIONBKEFECTINEGOCIO,	COD_VERSIONBKCONVENIO,COD_VERSIONRECELECTRO,
			COD_VERSIONRECMOTOS,	COD_VERSIONRECEFECTIVO,COD_VERSIONRECHIPOTECARIO,COD_VERSIONRECTARJETACREDITO,
			COD_VERSIONRECCONVENIO,VAL_SCOREBKELECTRO,	VAL_SCOREBKMOTOS,	VAL_SCOREBKEFECTIVO,
			VAL_SCOREBKHIPOTECARIO,VAL_SCOREBKTARJETACREDITO,VAL_SCOREBKEFECTINEGOCIO,VAL_SCOREBKCONVENIO,
			VAL_SCORERECELECTRO,VAL_SCORERECMOTOS,		VAL_SCORERECEFECTIVO,VAL_SCORERECHIPOTECARIO,
			VAL_SCORERECTARJETACREDITO,VAL_SCORERECCONVENIO,DES_SEGMENTOMODELO,DES_GRUPOBASE,
			DES_VERSIONMODELO,	DES_SCOREMODELO,		FLG_RECAL_SEG,		FLG_RECAL_ING,
			RECEFECTIVOFECCORTE,RECEFECTIVOKEYBD,		BKEFECTIVOFECCORTE,	BKEFECTIVOKEYBD,
			RECELECTROFECCORTE,	RECELECTROKEYBD,		BKELECTROFECCORTE,	BKELECTROKEYBD,
			RECMOTOSFECCORTE,	RECMOTOSKEYBD,			BKMOTOSFECCORTE,	BKMOTOSKEYBD,
			BKMICROFECCORTE,	BKMICROKEYBD,			FEC_PROCESO,		CODTIPOCLIENTE_EFECTINEGOCIO,	--#E2E19
			TIPOPROCESO,--#E2E19
			FlgCalificacionTodoNormal6UM, FlgWoccu,--#@COSR25
			TIPOPROCESOEFECTIVO, TIPOSUBPROCESOEFECTIVO, --#@E2E28
			NROEJECUCION)
		select P_FecCorte Fec_CorteEFE, P_FecCorteRCC Fec_CorteRCC, A.NROORDEN,
			A.CodTipoDocumento	COD_TIPODOCUMENTO,
			A.NumDocumento 	NRO_DOCUMENTO,
			''	DES_FILTROGENERAL,
			''	DES_FILTROELECTRO,
			''	DES_FILTROMOTOS,
			''	DES_FILTROEFECTIVO,
			''	DES_FILTROHIPOTECARIO,
			''	DES_FILTROCONVENIO,
			''	DES_FILTROTARJETACREDITO,
			''	DES_FILTROEFECTINEGOCIO,
			0	COD_TIPOCLIENTE,
			''	BANCA_ELECTRO,
			''	BANCA_MOTOS,
			''	BANCA_EFECTIVO,
			''	BANCA_HIPOTECARIO,
			''	BANCA_TC,
			''	BANCA_EFECTINEGOCIO,
			''	BANCA_CONVENIO,	
			''	RECELECTRO,
			''	RECMOTOS,
			''	RECEFECTIVO,
			''	RECTARJETA,
			''	RECCONVENIO,
			''	COD_GRUPOEFECTIVO,
			''	COD_GRUPOELECTRO,
			''	COD_GRUPOMOTOS,
			0	IMP_FASTTRACKELECTRO,
			0	IMP_FASTTRACKMOTOS,
			0	IMP_FASTTRACKEFECTIVO,
			0	IND_ACTUALIZARDATOS,
			null COD_PILOTOELECTRO,
			null COD_PILOTOMOTOS,
			null COD_PILOTOEFECTIVO,
			0	COD_VERSIONBKLECTRO,
			0	COD_VERSIONBKMOTOS,
			0	COD_VERSIONBKEFECTIVO,
			0	COD_VERSIONBKHIPOTECARIO,
			0	COD_VERSIONBKTC,
			0	COD_VERSIONBKEFECTINEGOCIO,
			0	COD_VERSIONBKCONVENIO,
			0	COD_VERSIONRECELECTRO,
			0	COD_VERSIONRECMOTOS,
			0	COD_VERSIONRECEFECTIVO,
			0	COD_VERSIONRECHIPOTECARIO,
			0	COD_VERSIONRECTC,
			0	COD_VERSIONRECCONVENIO,
			0	VAL_SCOREBKELECTRO,
			0	VAL_SCOREBKMOTOS,
			0	VAL_SCOREBKEFECTIVO,
			0	VAL_SCOREBKHIPOTECARIO,
			0	VAL_SCOREBKTC,
			0	VAL_SCOREBKEFECTINEGOCIO,
			0	VAL_SCOREBKCONVENIO,
			0	VAL_SCORERECELECTRO,
			0	VAL_SCORERECMOTOS,
			0	VAL_SCORERECEFECTIVO,
			0	VAL_SCORERECHIPOTECARIO,
			0	VAL_SCORERECTC,
			0	VAL_SCORERECCONVENIO,
			';;;;;;' DES_SEGMENTOMODELO,
			('' || ';' || '' || ';' || '' || ';' || '' || ';' || '' || ';' || '4' || ';' || '') AS DES_GRUPOBASE,
			'0;0;0;0;0;0;0'  DES_VERSIONMODELO,
			'0;0;0;0;0;0;0' COD_SCOREMODELO,
			0	FLG_RECAL_SEG,
			0	FLG_RECAL_ING,
			null	RECEFECTIVOFECCORTE,
			null	RECEFECTIVOKEYBD,
			null	BKEFECTIVOFECCORTE,
			0		BKEFECTIVOKEYBD,
			null	RECELECTROFECCORTE,
			null	RECELECTROKEYBD,
			null	BKELECTROFECCORTE,
			0		BKELECTROKEYBD,
			null	RECMOTOSFECCORTE,
			null	RECMOTOSKEYBD,
			null	BKMOTOSFECCORTE,
			0		BKMOTOSKEYBD,
			null	BKMICROFECCORTE,
			null	BKMICROKEYBD,
			now()	FEC_PROCESO,
			0	CODTIPOCLIenteEFN,
			3	TipoProceso,
			C.FlgCalificacionTodoNormal6UM,
			case when D.marcabaja = 0  then 'E'
				 when  A.CodFteRegistro = 'RCC' then 'R'
			end FlgWoccu, --#@COSR25
			'4'			as	TIPOPROCESOEFECTIVO,	--#@E2E28
			'0@0@0@6'	as	TIPOSUBPROCESOEFECTIVO, --#@E2E28
			V_NroEjecucion	NroEjecucion
		from PROD_EFECTIVA..PERSONAS A 
			left join DBO.UMD_FED_INTERFAZTXT			B ON B.NroOrden = A.NroOrden and B.Fec_CorteEFE		= P_FecCorte
			Left Join PROD_RCC..RCC_VariablesEspeciales	C on C.NroOrden = A.NroOrden and C.CodFecCorteRCC	= V_CodFecCorteRCC
			left join PROD_ANALITICA..BM_DetalleCreditos D on D.NroOrden= A.NroOrden and D.FechaCorte = P_FecCorte
		where A.codtipodocumento in (8,10,11,12,13) and B.NroOrden is null and (D.marcabaja = 0 or A.CodFteRegistro = 'RCC');
		V_NroRegistros := ROW_COUNT;
		If V_ejecutaLog = 1 then
			V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso, V_CodError, V_NroRegistros,''); 
		end if;
	end if;
	-- Fin #@COSR25 

		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 13.- Asignacion de Codigo para Clientes Electro - Optimización OB3
		-------------------------------------------------------------------------------------------------------------------------------------------------
		V_CodPaso := 13;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' THEN
		-- #@MLA29	Inicio
		DROP TABLE Tmp_NodosOB3 IF EXISTS;
		CREATE temp TABLE Tmp_NodosOB3 AS
		SELECT a.nroorden,A.COD_TIPOCLIENTE,
		CASE  WHEN COD_BKELECTRO = 'OB3' OR CODNODOOPTIMIZADOOB3 = 1 THEN CODNODOOPTIMIZADOOB3 ELSE -1 END AS CODNODOOPTIMIZADO_OB3_
		FROM UMD_FED_INTERFAZTXT A
		LEFT JOIN UMD_FED_RDGENERAL_SEMANAL B ON A.NROORDEN=B.NROORDEN AND A.FEC_CORTEEFE=B.FECCORTE
	 	where fec_corteefe=V_FecCorte
	--	and DES_FILTROELECTRO='' AND DES_FILTROGENERAL='' --NO tienen motivos de rechazo en el producto electro
		and COD_BKELECTRO<>'' -- Perfiles admitidos
		AND COD_TIPOCLIENTE=1 -- Bancarizados (OB3)
		DISTRIBUTE ON (nroorden)
		;				

		UPDATE  UMD_FED_INTERFAZTXT a  
		SET a.CODNODOOPTIMIZADO_OB3 = B.CODNODOOPTIMIZADO_OB3_ 
		FROM Tmp_NodosOB3 b 
		WHERE a.NROORDEN=b.nroorden
		and a.fec_corteefe=V_FecCorte
		AND a.COD_TIPOCLIENTE=b.COD_TIPOCLIENTE
		AND a.COD_TIPOCLIENTE=1
		;	
		-- #@MLA29 Final
		end if;
		
		-------------------------------------------------------------------------------------------------------------------------------------------------
		-- 14.- Elimina tablas temporales
		-------------------------------------------------------------------------------------------------------------------------------------------------
		
		V_CodPaso := 14;
		if substring (V_FlgEjecucion, V_CodPaso, 1) = 'S' then
			Drop Table DBO.TmpV_ReglasDuras_ if exists;
			DROP TABLE DBO.TMP_DETALLEBASEMASIVAS IF EXISTS;
			DROP TABLE DBO.TMP_DETALLEBASEMASIVASAPROB IF EXISTS;
			drop table DBO.TMP_DetalleBaseMasivaTC if exists;
			drop table DBO.tmp_GrupoB if exists;
			Drop Table DBO.TmpPerfilEfectivorecurrente If Exists;  
			Drop Table DBO.TmpPerfilEfectivobancarizado If Exists;
			Drop Table DBO.TmpPerfilElectrorecurrente If Exists;
			Drop Table DBO.TmpPerfilElectrobancarizado If Exists;
			Drop Table DBO.TmpPerfilMotosrecurrente If Exists;
			Drop Table DBO.TmpPerfilMotosbancarizado If Exists;
			Drop table DBO.TmpPerfilEfectiNegocio if exists;
			Drop table DBO.TmpPerfilTarjetaCredito if exists;
			Drop table DBO.Reperfilado if exists;
			DROP TABLE DBO.CUR_REPERFILADO IF EXISTS;
			Drop Table DBO.Tempo_EFECTIVO_G5 If Exists;
			Drop Table DBO.Tempo_TC_G5 If Exists;
			Drop Table DBO.Tempo_EFECTIVO_G7 If Exists;
			Drop Table DBO.Tempo_TC_G7 If Exists;
			Drop Table DBO.Tempo_ELECTRO_G0 if Exists;
			Drop Table DBO.Tempo_ELECTRO_G1 If Exists;
			Drop Table DBO.Tempo_MOTOS_G0 If Exists;
			Drop Table DBO.Tempo_MOTOS_G1 If Exists;
			DROP TABLE DBO.FED_TMP_RECHAZOS IF EXISTS;
			Drop Table DBO.TMP_UMD_FED_INTERFAZTXT If exists;
			DROP TABLE UMD_FED_INTERFAZTXT_ONLINE IF EXISTS;
			V_NroRegistros  := ROW_COUNT;
			If V_ejecutaLog = 1 Then
				V_ret:= PROD_PROCESOS.DBO.PI_ExecProcesoPasoMensaje( V_NroEjecucion, V_CodProceso,V_CodPaso,        V_CodError, V_NroRegistros,'');
			end if;
		end if;

		return V_NroRegistros;
	END;
END_PROC;