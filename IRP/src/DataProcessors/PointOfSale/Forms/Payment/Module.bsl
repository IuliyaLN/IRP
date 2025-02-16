
#Region Variables

&AtClient
Var AmountFractionDigitsCount; // Number

&AtClient
Var AmountDotIsActive; // Boolean

&AtClient
Var AmountFractionDigitsMaxCount; // Number

&AtClient
Var FormCanBeClosed; // Boolean

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Object.Amount = Parameters.Amount;
	Object.Branch = Parameters.Branch;
	Object.Workstation = Parameters.Workstation;
	Object.Discount = Parameters.Discount;
	ThisObject.IsAdvance = Parameters.IsAdvance;
	
	isReturn = Parameters.isReturn;
	RetailBasis = Parameters.RetailBasis;
	
	Items.Payment_PayByPaymentCard.Visible = Not isReturn;
	Items.Payment_ReturnPaymentByPaymentCard.Visible = isReturn;
	
	Items.PaymentsRRNCode.Visible = isReturn;
	
	FillPaymentTypes();
	FillPaymentMethods();
	
	If Not ThisObject.IsAdvance And ValueIsFilled(Parameters.RetailCustomer) Then
		AdvanceAmount = GetAdvanceByRetailCustomer(Parameters.Company, Parameters.Branch, Parameters.RetailCustomer);
		If ValueIsFilled(AdvanceAmount) Then
			AdvancePaymentType = GetAdvancePaymentType();
			If ValueIsFilled(AdvancePaymentType) Then	
				AdvancePayment = ThisObject.Payments.Add();
				AdvancePayment.Amount = Min(AdvanceAmount, Parameters.Amount);
				AdvancePayment.Description     = String(AdvancePaymentType);
				AdvancePayment.PaymentType     = AdvancePaymentType;
				AdvancePayment.PaymentTypeEnum = AdvancePaymentType.Type;
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CalculatePaymentsAmountTotal();
	FormatPaymentsAmountStringRows();
EndProcedure

&AtServer
Function GetAdvanceByRetailCustomer(_Company, _Branch, _RetailCustomer)
	Query = New Query();
	Query.Text = 
	"SELECT
	|	R2023B_AdvancesFromRetailCustomersBalance.AmountBalance AS Amount
	|FROM
	|	AccumulationRegister.R2023B_AdvancesFromRetailCustomers.Balance(, Company = &Company
	|	AND Branch = &Branch
	|	AND RetailCustomer = &RetailCustomer) AS R2023B_AdvancesFromRetailCustomersBalance";
	Query.SetParameter("Company", _Company);
	Query.SetParameter("Branch", _Branch);
	Query.SetParameter("RetailCustomer", _RetailCustomer);
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	If QuerySelection.Next() Then
		Return QuerySelection.Amount;
	EndIf;
	Return 0;
EndFunction
	
&AtServer
Function GetAdvancePaymentType()
	Query = New Query();
	Query.Text = 
	"SELECT
	|	PaymentTypes.Ref
	|FROM
	|	Catalog.PaymentTypes AS PaymentTypes
	|WHERE
	|	NOT PaymentTypes.DeletionMark
	|	AND PaymentTypes.Type = VALUE(Enum.PaymentTypes.Advance)";
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	If QuerySelection.Next() Then
		Return QuerySelection.Ref;
	EndIf;
	Return Undefined;
EndFunction	
	
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	ErrorMessages = New Array();

	If Not ThisObject.IsAdvance Then
		If ThisObject.PaymentsAmountTotal < Object.Amount Then
			ErrorMessages.Add(R().POS_s1);
		EndIf;
	EndIf;
	
	PaymentsValue = FormAttributeToValue("Payments");
	
	CashPaymentFilter = New Structure();
	CashPaymentFilter.Insert("PaymentTypeEnum", Enums.PaymentTypes.Cash);
	CashAmounts = PaymentsValue.Copy(CashPaymentFilter, "Amount");
	CashAmount = CashAmounts.Total("Amount");
	
	CardPaymentFilter = New Structure();
	CardPaymentFilter.Insert("PaymentTypeEnum", Enums.PaymentTypes.Card);
	CardAmounts = PaymentsValue.Copy(CardPaymentFilter, "Amount");
	CardAmount = CardAmounts.Total("Amount");
	
	If Not ThisObject.IsAdvance Then
		If CardAmount > Object.Amount Then
			ErrorMessages.Add(R().POS_s2);
		EndIf;
		
		If CardAmount = Object.Amount And CashAmount Then
			ErrorMessages.Add(R().POS_s3);
		EndIf;

		If Not ErrorMessages.Count() And PaymentsAmountTotal <> (Object.Amount + Object.Cashback) Then
			ErrorMessages.Add(R().POS_s4);
		EndIf;
	EndIf;
	
	If ErrorMessages.Count() Then
		Cancel = True;
		For Each ErrorMessage In ErrorMessages Do
			CommonFunctionsClientServer.ShowUsersMessage(ErrorMessage);
		EndDo;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure PaymentsOnChange(Item)
	
	CalculatePaymentsAmountTotal();
	FormatPaymentsAmountStringRows();
	
EndProcedure

&AtClient
Procedure PaymentsBeforeRowChange(Item, Cancel)
	CurrentData = Items.Payments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done") Then
		Cancel = True;
		CommonFunctionsClientServer.ShowUsersMessage(R().POS_Error_PaymentAlreadyDone);
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentsOnActivateRow(Item)
	
	CurrentData = Items.Payments.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Edited = False;
		CurrentData.AmountString = GetAmountString(CurrentData.Amount);
		Items.GroupPaymentInfo.Visible = Not CurrentData.Hardware.IsEmpty();
		
		If Items.GroupPaymentInfo.Visible And isReturn And Not RetailBasis.IsEmpty() Then
			RRNArray = GetRRNCode(CurrentData.PaymentType);
			Items.PaymentsRRNCode.ChoiceList.LoadValues(RRNArray);
		EndIf;
		SetEnablePaymentOptions(CurrentData);
	Else
		Items.GroupPaymentInfo.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEnablePaymentOptions(CurrentData)
	PaymentDone = CurrentData.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done");
	Items.Payment_PayByPaymentCard.Enabled = Not PaymentDone;
	Items.Payment_ReturnPaymentByPaymentCard.Enabled = Not PaymentDone;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Enter(Command)
	
	For Each PaymentRow In Payments Do
		If PaymentRow.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Card") Then
			If PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.NotUse") OR
				PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done") Then
					
			Else
				CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().POS_Error_CheckPaymentsbyCard, PaymentRow.PaymentType));
				Return;
			EndIf;
			
		EndIf;
	EndDo;
	
	If Not Payments.Count() And CashPaymentTypes.Count() Then
		ButtonSettings = POSClient.ButtonSettings();
		FillPropertyValues(ButtonSettings, CashPaymentTypes[0]);
		AdditionalParameters = New Structure();
		FillPayments(ButtonSettings, AdditionalParameters);
	EndIf;
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If Object.Cashback Then
		Row = Payments.Add();
		Row.PaymentType = CashPaymentTypes[0].PaymentType;
		Row.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Cash");
		Row.Account = CashPaymentTypes[0].Account;
		Row.Amount = -Object.Cashback;
	EndIf;
	
	ReturnValue = New Structure();
	ReturnValue.Insert("Payments", Payments);
	ReturnValue.Insert("ReceiptPaymentMethod", ReceiptPaymentMethod);
	FormCanBeClosed = True;
	Close(ReturnValue);
EndProcedure

&AtClient
Procedure CloseButton(Command)
	Close();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	For Each PaymentRow In Payments Do
		If PaymentRow.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Card")
			And PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done")
			And Not FormCanBeClosed Then
				Cancel = True;
				CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().POS_Error_OnClosePaymentAlreadyDone, PaymentRow.PaymentType));
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure Cash(Command)
	OpenPaymentForm(ThisObject.CashPaymentTypes, PredefinedValue("Enum.PaymentTypes.Cash"));
EndProcedure

&AtClient
Procedure Card(Command)
	OpenPaymentForm(ThisObject.BankPaymentTypes, PredefinedValue("Enum.PaymentTypes.Card"));
EndProcedure

&AtClient
Procedure Certificate(Command)
	Return;
EndProcedure

&AtClient
Procedure PaymentAgent(Command)
	OpenPaymentForm(ThisObject.PaymentAgentTypes, PredefinedValue("Enum.PaymentTypes.PaymentAgent"));
EndProcedure

&AtClient
Procedure NumPress(Command)
	
	PaymentsCount = 0;
	For Each Row In ThisObject.Payments Do
		If Row.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Advance") Then
			Continue;
		EndIf;
		PaymentsCount = PaymentsCount + 1;
	EndDo;
	
//	If Not Payments.Count() And CashPaymentTypes.Count() Then
	If Not PaymentsCount And CashPaymentTypes.Count() Then
		ButtonSettings = POSClient.ButtonSettings();
		FillPropertyValues(ButtonSettings, CashPaymentTypes[0]);
		AdditionalParameters = New Structure();
		FillPayments(ButtonSettings, AdditionalParameters);
	EndIf;
	
	NumButtonPress(Command.Name);
	CurrentItem = Items.Enter;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenPaymentForm(PaymentTypesTable, PaymentType)

	If PaymentTypesTable.Count() > 1 Then
		NotifyParameters = New Structure();
		NotifyDescription = New NotifyDescription("FillPayments", ThisObject, NotifyParameters);
		PayButtons = New Array();
		For Each CollectionItem In PaymentTypesTable Do
			ButtonSettings = POSClient.ButtonSettings();
			FillPropertyValues(ButtonSettings, CollectionItem);
			ButtonSettings.PaymentTypeEnum = PaymentType;
			PayButtons.Add(ButtonSettings);
		EndDo;
		
		OpeningFormParameters = New Structure();
		OpeningFormParameters.Insert("PayButtons", PayButtons);
		OpenForm("DataProcessor.PointOfSale.Form.PaymentTypes", OpeningFormParameters, ThisObject, UUID, , ,
			NotifyDescription, FormWindowOpeningMode.LockWholeInterface);
	Else
		ButtonSettings = POSClient.ButtonSettings();

		FillPropertyValues(ButtonSettings, PaymentTypesTable[0]);
		ButtonSettings.PaymentTypeEnum = PaymentType;
		ChoiceEndAdditionalParameters = New Structure();
		FillPayments(ButtonSettings, ChoiceEndAdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculatePaymentsAmountTotal()
	ThisObject.PaymentsAmountTotal = Payments.Total("Amount");
	
	CashFilter = New Structure();
	CashFilter.Insert("PaymentTypeEnum", PredefinedValue("Enum.PaymentTypes.Cash"));
	CashRows = Payments.FindRows(CashFilter);
	
	PaymentCashAmount = 0;
	For Each CashRow In CashRows Do
		PaymentCashAmount = PaymentCashAmount + CashRow.Amount;
	EndDo;
	
	If ThisObject.PaymentsAmountTotal > Object.Amount 
		And ThisObject.PaymentsAmountTotal - Object.Amount <= PaymentCashAmount Then
		CashbackValue = ThisObject.PaymentsAmountTotal - Object.Amount;
	Else
		CashbackValue = 0;
	EndIf;
	
	Object.Cashback = CashbackValue;
EndProcedure

&AtClient
Procedure FormatPaymentsAmountStringRows()
	
	For Each Row In Payments Do
		Row.AmountString = GetAmountString(Row.Amount);
	EndDo;
	
EndProcedure

&AtClient
Procedure NumButtonPress(CommandName)
	
	CurrentData = Items.Payments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	If Not CurrentData.Edited Then
		CurrentData.Amount = 0;
		CurrentData.Edited = True;
		AmountDotIsActive = False;
		AmountFractionDigitsCount = 0;
	EndIf;

	ButtonValue = StrReplace(CommandName, "Numpad", "");

	If ButtonValue = "Dot" Then
		ProcessDotButtonPress(CurrentData);
	ElsIf ButtonValue = "0" Then
		ProcessZeroButtonPress(CurrentData);
	ElsIf ButtonValue = "Backspace" Then
		ProcessBackspaceButtonPress(CurrentData);
	ElsIf ButtonValue = "Clear" Then
		ProcessClearButtonPress(CurrentData);
	Else
		ProcessDigitButtonPress(CurrentData, ButtonValue);
	EndIf;

	If AmountDotIsActive Then
		If AmountFractionDigitsCount Then
			NFDValue = "NFD=" + String(AmountFractionDigitsCount) + ";";
			AmountString = Format(CurrentData.Amount, NFDValue);
		Else
			AmountString = String(CurrentData.Amount) + Mid(String(0.1), 2, 1);
		EndIf;
	Else
		AmountString = String(CurrentData.Amount);
	EndIf;
	CurrentData.AmountString = AmountString;
	CalculatePaymentsAmountTotal();
	
EndProcedure

&AtClient
Procedure ProcessDotButtonPress(CurrentData)
	
	If Not AmountDotIsActive Then
		AmountDotIsActive = True;
		AmountFractionDigitsCount = 0;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessZeroButtonPress(CurrentData)
	
	Ten = 10;
	If AmountDotIsActive Then
		If (AmountFractionDigitsCount + 1) < AmountFractionDigitsMaxCount Then
			AmountFractionDigitsCount = AmountFractionDigitsCount + 1;
		EndIf;
	Else
		CurrentData.Amount = CurrentData.Amount * Ten;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessBackspaceButtonPress(CurrentData)
	
	Ten = 10;
	If AmountDotIsActive Then
		If AmountFractionDigitsCount Then
			AmountFractionDigitsCount = AmountFractionDigitsCount - 1;
			AmountFractionDigits = CurrentData.Amount - Int(CurrentData.Amount);
			AmountValue = Int(AmountFractionDigits * Pow(Ten, AmountFractionDigitsCount)) / Pow(Ten,
				AmountFractionDigitsCount);
			CurrentData.Amount = Int(CurrentData.Amount) + AmountValue;
		Else
			AmountDotIsActive = False;
		EndIf;
	Else
		If Int(CurrentData.Amount / Ten) Then
			CurrentData.Amount = Int(CurrentData.Amount / Ten);
		Else
			CurrentData.Amount = 0;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessClearButtonPress(CurrentData)
	
	CurrentData.Amount = 0;
	CurrentData.Edited = False;
	AmountDotIsActive = False;
	AmountFractionDigitsCount = 0;
	
EndProcedure

&AtClient
Procedure ProcessDigitButtonPress(CurrentData, Val ButtonValue)
	
	Ten = 10;
	CurrentAmountValue = CurrentData.Amount;
	If AmountDotIsActive Then
		If AmountFractionDigitsCount < AmountFractionDigitsMaxCount Then
			CurrentData.Amount = CurrentData.Amount + Number(ButtonValue) / Pow(Ten, AmountFractionDigitsCount + 1);
			AmountFractionDigitsCount = AmountFractionDigitsCount + 1;
		EndIf;
	Else
		CurrentData.Amount = CurrentData.Amount * Ten + Number(ButtonValue);
		If (CurrentAmountValue * Ten + Number(ButtonValue)) <> CurrentData.Amount Then
			CurrentData.Amount = CurrentAmountValue;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillPaymentTypes()
	
	FillPaymentsAtServer();
	
EndProcedure

&AtServer
Procedure FillPaymentsAtServer()
	CashPaymentTypesValue = GetCashPaymentTypesValue();
	ValueToFormAttribute(CashPaymentTypesValue, "CashPaymentTypes");

	BankPaymentTypesValue = GetBankPaymentTypesValue(Object.Branch);
	ValueToFormAttribute(BankPaymentTypesValue, "BankPaymentTypes");

	If Not ThisObject.IsAdvance Then
		PaymentAgentValue = GetPaymentAgentTypesValue(Object.Branch);
		ValueToFormAttribute(PaymentAgentValue, "PaymentAgentTypes");
	EndIf;
	
	Items.Cash.Enabled = ThisObject.CashPaymentTypes.Count();
	Items.Card.Enabled = ThisObject.BankPaymentTypes.Count();
	Items.PaymentAgent.Enabled = ThisObject.PaymentAgentTypes.Count();
EndProcedure

&AtServer
Procedure FillPaymentMethods()
	
	ReceiptPaymentMethod = Enums.ReceiptPaymentMethods.FullCalculation;
	
EndProcedure

// Get bank payment types value.
// 
// Parameters:
//  Branch - CatalogRef.BusinessUnits - Branch
// 
// Returns:
//  ValueTable - Get bank payment types value:
// * PaymentType - CatalogRef.PaymentTypes -
// * Description - DefinedType.typeDescription -
// * BankTerm - CatalogRef.BankTerms -
// * Account - CatalogRef.CashAccounts -
// * Percent - Number -
// * PaymentTypeParent - CatalogRef.PaymentTypes -
// * ParentDescription - DefinedType.typeDescription -
&AtServer
Function GetBankPaymentTypesValue(Branch)

	Query = New Query();
	Query.Text = "SELECT
				 |	BranchBankTerms.BankTerm
				 |FROM
				 |	InformationRegister.BranchBankTerms AS BranchBankTerms
				 |WHERE
				 |	BranchBankTerms.Branch = &Branch";
	Query.SetParameter("Branch", Branch);
	QueryUnload = Query.Execute().Unload();
	BankTerms = QueryUnload.UnloadColumn("BankTerm");

	Query = New Query();
	Query.Text = "SELECT
				 |	PaymentTypes.PaymentType,
				 |	PaymentTypes.PaymentType.Presentation AS Description,
				 |	PaymentTypes.Ref AS BankTerm,
				 |	PaymentTypes.Account,
				 |	PaymentTypes.Percent,
				 |	PaymentTypes.PaymentType.Parent AS PaymentTypeParent,
				 |	PaymentTypes.PaymentType.Parent.Presentation AS ParentDescription
				 |FROM
				 |	Catalog.BankTerms.PaymentTypes AS PaymentTypes
				 |WHERE
				 |	PaymentTypes.Ref In (&BankTerms)";
	Query.SetParameter("BankTerms", BankTerms);
	BankPaymentTypesValue = Query.Execute().Unload();
	Return BankPaymentTypesValue
	
EndFunction

// Get cash payment types value.
// 
// Returns:
//  ValueTable - Get cash payment types value:
//  	*PaymentType - CatalogRef.PaymentTypes
//  	*Description - DefinedType.typeDescription
//  	*Account - CatalogRef.CashAccounts
&AtServer
Function GetCashPaymentTypesValue()
	Query = New Query();
	Query.Text = "SELECT
	|	PaymentTypes.Ref AS PaymentType,
	|	PaymentTypes.Description_en AS Description,
	|	&CashAccount AS Account,
	|	VALUE(Enum.PaymentTypes.Cash) AS PaymentTypeEnum
	|FROM
	|	Catalog.PaymentTypes AS PaymentTypes
	|WHERE
	|	PaymentTypes.Type = VALUE(Enum.PaymentTypes.Cash)
	|	AND NOT PaymentTypes.DeletionMark";
	Query.SetParameter("CashAccount", Object.Workstation.CashAccount);
	Return Query.Execute().Unload();
EndFunction

&AtServer
Function GetPaymentAgentTypesValue(Branch)
	Query = New Query();
	Query.Text = 
		"SELECT
		|	PaymentTypes.Ref AS PaymentType,
		|	PaymentTypes.Description_en AS Description
		|FROM
		|	Catalog.PaymentTypes AS PaymentTypes
		|WHERE
		|	PaymentTypes.Type = VALUE(Enum.PaymentTypes.PaymentAgent)
		|	AND NOT PaymentTypes.DeletionMark
		|	AND PaymentTypes.Branch = &Branch";
	Query.SetParameter("Branch", Branch);
	Return Query.Execute().Unload();
EndFunction

// Fill payments
// 
// Parameters:
//  Result - See POSClient.ButtonSettings
//  AdditionalParameters - Arbitrary - Additional parameters
&AtClient
Procedure FillPayments(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;

	FoundPayment = ThisObject.Payments.FindRows(Result);
	If FoundPayment.Count() AND Result.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Cash") Then
		Row = FoundPayment[0];
		Row.Amount = 0;
	Else
		Row = Payments.Add();
		Row.PaymentType = Result.PaymentType;
		Row.BankTerm = Result.BankTerm;
		Row.PaymentTypeEnum = Result.PaymentTypeEnum;
		
		DefaultPaymentFilter = New Structure;
		DefaultPaymentFilter.Insert("PaymentType", Result.PaymentType);
		
		If Result.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Card") Then
			DefaultPaymentFilter.Insert("BankTerm", Result.BankTerm);
			DefaultPayment = BankPaymentTypes.FindRows(DefaultPaymentFilter);
			Row.Percent = DefaultPayment[0].Percent;
			Row.Account = DefaultPayment[0].Account;
		ElsIf Result.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.PaymentAgent") Then
			DefaultPayment = CashPaymentTypes.FindRows(DefaultPaymentFilter);
			//DefaultPayment.Percent = ????
		Else
			DefaultPayment = CashPaymentTypes.FindRows(DefaultPaymentFilter);
			Row.Account = DefaultPayment[0].Account;
		EndIf;
	EndIf;
	
	If (Object.Amount - Payments.Total("Amount")) <= 0 Then
		RemainingAmount = 0;
	Else
		RemainingAmount = Object.Amount - Payments.Total("Amount");
	EndIf;
	
	Row.Amount = RemainingAmount;
	
	If Result.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Cash") Then
		Row.AmountString = GetAmountString(Row.Amount);
	ElsIf Result.PaymentTypeEnum = PredefinedValue("Enum.PaymentTypes.Card") Then
		Settings = EquipmentAcquiringServer.GetAcquiringHardwareSettings();
		Settings.Account = Row.Account;
		Row.Hardware = EquipmentAcquiringServer.GetAcquiringHardware(Settings);
		If Row.Hardware.IsEmpty() Then
			Row.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.NotUse");
		Else
			Row.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.New");
		EndIf;
	EndIf;
	
	Items.Payments.CurrentRow = Row.GetID();
	Items.Payments.CurrentData.Edited = False;
	CurrentItem = Items.Enter;
	
	CalculatePaymentsAmountTotal();
	FormatPaymentsAmountStringRows();
EndProcedure

&AtClient
Function GetAmountString(Val AmountValue)
	
	Return Format(AmountValue, "NFD=" + Format(AmountFractionDigitsMaxCount, "NG=0;"));
	
EndFunction

&AtServerNoContext
Function GetFractionDigitsMaxCount()
	
	Return Metadata.DefinedTypes.typeAmount.Type.NumberQualifiers.FractionDigits;
	
EndFunction

#EndRegion

#Region Acquiring

&AtClient
Async Procedure Payment_PayByPaymentCard(Command)
	
	PaymentRow = Items.Payments.CurrentData;
	
	If PaymentRow = Undefined Then
		Return;
	EndIf;
	
	
	PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.New");
	
	PaymentSettings = EquipmentAcquiringClient.PayByPaymentCardSettings();
	PaymentSettings.In.Amount = PaymentRow.Amount;
	PaymentSettings.Form.ElementToLock = ThisObject;
	
	Result = Await EquipmentAcquiringClient.PayByPaymentCard(PaymentRow.Hardware, PaymentSettings);
	PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
	If Result Then
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done");
		PaymentRow.RRNCode = PaymentSettings.Out.RRNCode;
	Else
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Error");
	EndIf;
	SetEnablePaymentOptions(PaymentRow);
EndProcedure

&AtClient
Async Procedure Payment_ReturnPaymentByPaymentCard(Command)
	PaymentRow = Items.Payments.CurrentData;
	
	If PaymentRow = Undefined Then
		Return;
	EndIf;
	
	PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.New");
	
	PaymentSettings = EquipmentAcquiringClient.ReturnPaymentByPaymentCardSettings();
	PaymentSettings.In.Amount = PaymentRow.Amount;
	PaymentSettings.InOut.RRNCode = PaymentRow.RRNCode;
	PaymentSettings.Form.ElementToLock = ThisObject;
	
	If Await EquipmentAcquiringClient.ReturnPaymentByPaymentCard(PaymentRow.Hardware, PaymentSettings) Then
		PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done");
	Else
		PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Error");
	EndIf;
	SetEnablePaymentOptions(PaymentRow);
EndProcedure

&AtClient
Async Procedure Payment_CancelPaymentByPaymentCard(Command)
	PaymentRow = Items.Payments.CurrentData;
	
	If PaymentRow = Undefined Then
		Return;
	EndIf;
	
	PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.New");
	
	PaymentSettings = EquipmentAcquiringClient.CancelPaymentByPaymentCardSettings();
	PaymentSettings.In.Amount = PaymentRow.Amount;
	
	If Await EquipmentAcquiringClient.CancelPaymentByPaymentCard(PaymentRow.Hardware, PaymentSettings) Then
		PaymentSettings.Delete("In");
		PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done");
	Else
		PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Error");
	EndIf;
EndProcedure

&AtClient
Async Procedure Payment_EmergencyReversal(Command)
	PaymentRow = Items.Payments.CurrentData;
	
	If PaymentRow = Undefined Then
		Return;
	EndIf;
	
	PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.New");
	
	PaymentSettings = EquipmentAcquiringClient.EmergencyReversalSettings();
	
	If Await EquipmentAcquiringClient.EmergencyReversal(PaymentRow.Hardware, PaymentSettings) Then
		PaymentSettings.Delete("In");
		PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Done");
	Else
		PaymentRow.PaymentInfo = CommonFunctionsServer.SerializeJSON(PaymentSettings);
		PaymentRow.AcquiringPaymentStatus = PredefinedValue("Enum.AcquiringPaymentStatus.Error");
	EndIf;
EndProcedure

&AtServer
Function GetRRNCode(PaymentType)
	Rows = RetailBasis.Payments.FindRows(New Structure("PaymentType", PaymentType));
	Array = New Array;
	For Each Row In Rows Do
		Array.Add(Row.RRNCode);
	EndDo;
	Return Array;
EndFunction


#EndRegion

AmountFractionDigitsCount = 0;
AmountDotIsActive = False;
AmountFractionDigitsMaxCount = GetFractionDigitsMaxCount();
FormCanBeClosed = False;
	