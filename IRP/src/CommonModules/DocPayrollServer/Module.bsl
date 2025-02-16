#Region FORM

Procedure OnCreateAtServer(Object, Form, Cancel, StandardProcessing) Export
	DocumentsServer.OnCreateAtServer(Object, Form, Cancel, StandardProcessing);
	If Form.Parameters.Key.IsEmpty() Then
		SetGroupItemsList(Object, Form);
		DocumentsClientServer.ChangeTitleGroupTitle(Object, Form);
	EndIf;
	ViewServer_V2.OnCreateAtServer(Object, Form, "");
EndProcedure

Procedure AfterWriteAtServer(Object, Form, CurrentObject, WriteParameters) Export
	DocumentsClientServer.ChangeTitleGroupTitle(CurrentObject, Form);
EndProcedure

Procedure OnReadAtServer(Object, Form, CurrentObject) Export
	If Not Form.GroupItems.Count() Then
		SetGroupItemsList(Object, Form);
	EndIf;
	DocumentsClientServer.ChangeTitleGroupTitle(CurrentObject, Form);
	LockDataModificationPrivileged.LockFormIfObjectIsLocked(Form, CurrentObject);
EndProcedure

#EndRegion

#Region _TITLE

Procedure SetGroupItemsList(Object, Form)
	AttributesArray = New Array();
	AttributesArray.Add("Company");
	DocumentsServer.DeleteUnavailableTitleItemNames(AttributesArray);
	For Each Attr In AttributesArray Do
		Form.GroupItems.Add(Attr, ?(ValueIsFilled(Form.Items[Attr].Title), Form.Items[Attr].Title,
			Object.Ref.Metadata().Attributes[Attr].Synonym + ":" + Chars.NBSp));
	EndDo;
EndProcedure

#EndRegion

#Region LIST_FORM

Procedure OnCreateAtServerListForm(Form, Cancel, StandardProcessing) Export
	DocumentsServer.OnCreateAtServerListForm(Form, Cancel, StandardProcessing);
EndProcedure

#EndRegion

#Region CHOICE_FORM

Procedure OnCreateAtServerChoiceForm(Form, Cancel, StandardProcessing) Export
	DocumentsServer.OnCreateAtServerChoiceForm(Form, Cancel, StandardProcessing);
EndProcedure

#EndRegion

Function GetPayrolls(Parameters) Export
	ResultTable = New ValueTable();
	ResultTable.Columns.Add("Employee");
	ResultTable.Columns.Add("Position");
	ResultTable.Columns.Add("AccrualAndDeductionType");
	ResultTable.Columns.Add("Amount");
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	T9520S_TimeSheetInfo.Date AS Date,
	|	T9520S_TimeSheetInfo.Employee AS Employee,
	|	T9520S_TimeSheetInfo.Position AS Position,
	|	T9520S_TimeSheetInfo.AccrualAndDeductionType AS AccrualAndDeductionType
	|FROM
	|	InformationRegister.T9520S_TimeSheetInfo AS T9520S_TimeSheetInfo
	|WHERE
	|	T9520S_TimeSheetInfo.Date BETWEEN BEGINOFPERIOD(&BeginDate, DAY) AND ENDOFPERIOD(&EndDate, DAY)
	|	AND T9520S_TimeSheetInfo.Company = &Company
	|	AND T9520S_TimeSheetInfo.Branch = &Branch";
	Query.SetParameter("BeginDate", Parameters.BeginDate);
	Query.SetParameter("EndDate"  , Parameters.EndDate);
	Query.SetParameter("Company"  , Parameters.Company);
	Query.SetParameter("Branch"   , Parameters.Branch);
	
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	
	While QuerySelection.Next() Do
		Value = SalaryServerReuse.GetAccualAndDeductionValue(QuerySelection.Date, 
			QuerySelection.Employee,
			QuerySelection.Position,
			QuerySelection.AccrualAndDeductionType);
		CountDays = SalaryServerReuse.GetWorkDays(Parameters.BeginDate,
			Parameters.EndDate,
			QuerySelection.AccrualAndDeductionType);
	EndDo;
	
	Return ResultTable;
EndFunction

Function _MonthlySalary()
		
EndFunction


