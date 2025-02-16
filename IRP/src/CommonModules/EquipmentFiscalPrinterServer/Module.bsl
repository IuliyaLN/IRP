#Region Public

Function PrepareReceiptData(RetailSalesReceipt) Export
	Var Str;
	Str = New Structure;
	Str.Insert("CashierName", String(RetailSalesReceipt.Author));
	If TypeOf(RetailSalesReceipt.Ref) = Type("DocumentRef.RetailSalesReceipt") Then
		Str.Insert("OperationType", 1);
	Else
		Str.Insert("OperationType", 2);
	EndIf;
	Str.Insert("TaxationSystem", 0);	//TODO: TaxSystem choice 
	FiscalStrings = New Array;
	For Each Item In RetailSalesReceipt.ItemList Do
		RowFilter = New Structure();
		RowFilter.Insert("Key", Item.Key);
		SLNRows = RetailSalesReceipt.SerialLotNumbers.FindRows(RowFilter);
		TaxRows = RetailSalesReceipt.TaxList.FindRows(RowFilter);
		If TypeOf(RetailSalesReceipt.Ref) = Type("DocumentRef.RetailSalesReceipt") Then
			CBRows = RetailSalesReceipt.ConsignorBatches.FindRows(RowFilter);
		Else
			CBRows = New Array;
		EndIf;
		FiscalStringData = New Structure();
		FiscalStringData.Insert("AmountWithDiscount", Item.TotalAmount);
		FiscalStringData.Insert("DiscountAmount", Item.OffersAmount);
		If SLNRows.Count() = 1 Then
			If IsBlankString(SLNRows[0].SerialLotNumber.CodeString) Then
				FiscalStringData.Insert("CalculationSubject", "32");	//https://its.1c.ru/db/metod8dev#content:4829:hdoc:signcalculationobject	
			Else
				FiscalStringData.Insert("MarkingCode", SLNRows[0].SerialLotNumber.CodeString);	//TODO: Marking defenition
				FiscalStringData.Insert("CalculationSubject", "33");	//https://its.1c.ru/db/metod8dev#content:4829:hdoc:signcalculationobject
			EndIf;
		ElsIf SLNRows.Count() > 1 Then
			Raise("A few SerialLotNumber found!");
		EndIf;
		FiscalStringData.Insert("MeasureOfQuantity", "255");
		FiscalStringData.Insert("Name", String(Item.Item) + " " + String(Item.ItemKey));
		FiscalStringData.Insert("Quantity", Item.Quantity);
		If RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.FullPrepayment Then
			FiscalStringData.Insert("PaymentMethod", 1);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.PartialPrepayment Then
			FiscalStringData.Insert("PaymentMethod", 2);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.AdvancePayment Then
			FiscalStringData.Insert("PaymentMethod", 3);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.FullCalculation Then
			FiscalStringData.Insert("PaymentMethod", 4);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.PartialSettlementAndCredit Then
			FiscalStringData.Insert("PaymentMethod", 5);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.TransferOnCredit Then
			FiscalStringData.Insert("PaymentMethod", 6);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.LoanPayment Then
			FiscalStringData.Insert("PaymentMethod", 7);
		Else
			FiscalStringData.Insert("PaymentMethod", 4);
		EndIf;
		FiscalStringData.Insert("PriceWithDiscount", Round(Item.TotalAmount / Item.Quantity, 2));
		If TaxRows.Count() > 0 Then
			If TaxRows[0].TaxRate.NoRate Then
				FiscalStringData.Insert("VATRate", "none");
				FiscalStringData.Insert("VATAmount", 0);  
			Else
				FiscalStringData.Insert("VATRate", Format(TaxRows[0].TaxRate.Rate, "NZ=0; NG=0;"));
				FiscalStringData.Insert("VATAmount", TaxRows[0].Amount);
			EndIf;
			
		Else
			Raise("Tax isn't found!");
		EndIf;
		If CBRows.Count() > 0 Then
			VendorData = New Structure;
			If TypeOf(CBRows[0].Batch) = Type("DocumentRef.OpeningEntry") Then
				VendorData.Insert("VendorINN", CBRows[0].Batch.LegalNameConsignor.TaxID);
				VendorData.Insert("VendorName", String(CBRows[0].Batch.LegalNameConsignor));
				VendorData.Insert("VendorPhone", "");
			Else
				VendorData.Insert("VendorINN", CBRows[0].Batch.LegalName.TaxID);
				VendorData.Insert("VendorName", String(CBRows[0].Batch.LegalName));
				VendorData.Insert("VendorPhone", "");
			EndIf;
			FiscalStringData.Insert("CalculationAgent", "5");
			FiscalStringData.Insert("VendorData", VendorData);
		EndIf;
		FiscalStrings.Add(FiscalStringData);
	EndDo;
	
	Str.Insert("FiscalStrings", FiscalStrings);
	Str.Insert("TextStrings", New Array);
	
	Str.Insert("Cash", 0);
	Str.Insert("ElectronicPayment", 0);
	Str.Insert("PrePayment", 0);
	Str.Insert("PostPayment", 0);
	Str.Insert("Barter", 0);
	
	For Each Payment In RetailSalesReceipt.Payments Do
		If RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.FullPrepayment Then
			Str.Insert("PrePayment", Str.PrePayment + Payment.Amount);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.PartialPrepayment Then
			Str.Insert("PrePayment", Str.PrePayment + Payment.Amount);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.AdvancePayment Then
			Str.Insert("PrePayment", Str.PrePayment + Payment.Amount);
		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.FullCalculation Then
			If Payment.PaymentType.Type = Enums.PaymentTypes.Cash Then
				Str.Insert("Cash", Str.Cash + Payment.Amount);
			ElsIf Payment.PaymentType.Type = Enums.PaymentTypes.Card Then
				Str.Insert("ElectronicPayment", Str.ElectronicPayment + Payment.Amount);
			ElsIf Payment.PaymentType.Type = Enums.PaymentTypes.PaymentAgent Then
				Str.Insert("PostPayment", Str.PostPayment + Payment.Amount);
			Else
				Str.Insert("Cash", Str.Cash + Payment.Amount);
			EndIf;
//		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.PartialSettlementAndCredit Then
//			Str.Insert("PrePayment", Str.PrePayment + Payment.Amount);
//		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.TransferOnCredit Then
//			Str.Insert("PrePayment", Str.PrePayment + Payment.Amount);
//		ElsIf RetailSalesReceipt.PaymentMethod = Enums.ReceiptPaymentMethods.LoanPayment Then
//			Str.Insert("PrePayment", Str.PrePayment + Payment.Amount);
		Else
			If Payment.PaymentType.Type = Enums.PaymentTypes.Cash Then
				Str.Insert("Cash", Str.Cash + Payment.Amount);
			ElsIf Payment.PaymentType.Type = Enums.PaymentTypes.Card Then
				Str.Insert("ElectronicPayment", Str.ElectronicPayment + Payment.Amount);
			ElsIf Payment.PaymentType.Type = Enums.PaymentTypes.PaymentAgent Then
				Str.Insert("PostPayment", Str.PostPayment + Payment.Amount);
			Else
				Str.Insert("Cash", Str.Cash + Payment.Amount);
			EndIf;
		EndIf;
	EndDo;
	
	Return Str;
EndFunction

Procedure SetFiscalStatus(DocumentRef, Status = "Prepaired", FiscalResponse = "", DataPresentation = "") Export
	If Status = "Prepaired" Then
		InformationRegisters.DocumentFiscalStatus.SetStatus(DocumentRef
																, Enums.DocumentFiscalStatuses.Prepaired);
	ElsIf Status = "Printed" Then
		InformationRegisters.DocumentFiscalStatus.SetStatus(DocumentRef
																, Enums.DocumentFiscalStatuses.Printed
																, FiscalResponse
																, DataPresentation);
	ElsIf Status = "FiscalReturnedError" Then
		InformationRegisters.DocumentFiscalStatus.SetStatus(DocumentRef
																, Enums.DocumentFiscalStatuses.FiscalReturnedError
																, FiscalResponse);
	ElsIf Status = "NotPrinted" Then
		InformationRegisters.DocumentFiscalStatus.SetStatus(DocumentRef
																, Enums.DocumentFiscalStatuses.NotPrinted);
	EndIf;
EndProcedure

Function GetStatusData(DocumentRef) Export
	FiscalStatus = InformationRegisters.DocumentFiscalStatus.GetStatusData(DocumentRef);
	Return FiscalStatus;
EndFunction

#EndRegion
	