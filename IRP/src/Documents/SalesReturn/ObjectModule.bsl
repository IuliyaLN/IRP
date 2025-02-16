Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	If DataExchange.Load Then
		Return;
	EndIf;

	Parameters = CurrenciesClientServer.GetParameters_V3(ThisObject);
	CurrenciesClientServer.DeleteRowsByKeyFromCurrenciesTable(ThisObject.Currencies);
	CurrenciesServer.UpdateCurrencyTable(Parameters, ThisObject.Currencies);

	ThisObject.DocumentAmount = ThisObject.ItemList.Total("TotalAmount");
	ThisObject.AdditionalProperties.Insert("OriginalDocumentDate", PostingServer.GetOriginalDocumentDate(ThisObject));
EndProcedure

Procedure OnWrite(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
EndProcedure

Procedure BeforeDelete(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
EndProcedure

Procedure Posting(Cancel, PostingMode)
	PostingServer.Post(ThisObject, Cancel, PostingMode, ThisObject.AdditionalProperties);
EndProcedure

Procedure UndoPosting(Cancel)
	UndopostingServer.Undopost(ThisObject, Cancel, ThisObject.AdditionalProperties);
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	If FillingData = Undefined Then
		FillingData = New Structure();
		FillingData.Insert("TransactionType", Enums.SalesReturnTransactionTypes.ReturnFromCustomer);
		FillPropertyValues(ThisObject, FillingData);
		ControllerClientServer_V2.SetReadOnlyProperties(ThisObject, FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure") And FillingData.Property("BasedOn") Then
		PropertiesHeader = RowIDInfoServer.GetSeparatorColumns(ThisObject.Metadata());
		FillPropertyValues(ThisObject, FillingData, PropertiesHeader);
		LinkedResult = RowIDInfoServer.AddLinkedDocumentRows(ThisObject, FillingData);
		ControllerClientServer_V2.SetReadOnlyProperties_RowID(ThisObject, PropertiesHeader, LinkedResult.UpdatedProperties);
	EndIf;
EndProcedure

Procedure OnCopy(CopiedObject)
	LinkedTables = New Array();
	LinkedTables.Add(SpecialOffers);
	LinkedTables.Add(TaxList);
	LinkedTables.Add(Currencies);
	LinkedTables.Add(SerialLotNumbers);
	DocumentsServer.SetNewTableUUID(ItemList, LinkedTables);
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	If DocumentsServer.CheckItemListStores(ThisObject) Then
		Cancel = True;
	EndIf;

	If Not SerialLotNumbersServer.CheckFilling(ThisObject) Then
		Cancel = True;
	EndIf;
	
	For Each Row In ThisObject.ItemList Do
		If Not ValueIsFilled(Row.SalesInvoice) And Not ValueIsFilled(Row.LandedCost) Then
			Cancel = True;
			CommonFunctionsClientServer.ShowUsersMessage(R().Error_114,
			"ItemList[" + Format((Row.LineNumber - 1), "NZ=0; NG=0;") + "].LandedCost", ThisObject);
		EndIf;
	EndDo;
	
	If Not Cancel = True Then
		LinkedFilter = RowIDInfoClientServer.GetLinkedDocumentsFilter_SR(ThisObject);
		RowIDInfoTable = ThisObject.RowIDInfo.Unload();
		ItemListTable = ThisObject.ItemList.Unload(, "Key, LineNumber, ItemKey, Store");
		RowIDInfoPrivileged.FillCheckProcessing(ThisObject, Cancel, LinkedFilter, RowIDInfoTable, ItemListTable);
	EndIf;

	If ValueIsFilled(ThisObject.Company) Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	ItemList.LineNumber AS LineNumber,
		|	ItemList.Key AS Key,
		|	CAST(ItemList.Store AS Catalog.Stores) AS Store
		|into ttItemList
		|FROM
		|	&ItemList AS ItemList
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RowIDInfo.Key AS Key,
		|	RowIDInfo.Basis AS Basis
		|into ttRowIDInfo
		|FROM
		|	&RowIDInfo AS RowIDInfo
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ItemList.LineNumber AS LineNumber,
		|	ItemList.Store AS Store,
		|	ItemList.Store.Company AS StoreCompany,
		|	RowIDInfo.Basis AS Basis
		|FROM
		|	ttItemList AS ItemList
		|		LEFT JOIN ttRowIDInfo AS RowIDInfo
		|		ON ItemList.Key = RowIDInfo.Key
		|
		|ORDER BY
		|	LineNumber";
		Query.SetParameter("ItemList", ThisObject.ItemList.Unload());
		Query.SetParameter("RowIDInfo", ThisObject.RowIDInfo.Unload());
		QuerySelection = Query.Execute().Select();
		While QuerySelection.Next() Do
			If ValueIsFilled(QuerySelection.Basis) Then
				Continue;
			ElsIf ValueIsFilled(QuerySelection.StoreCompany) And Not QuerySelection.StoreCompany = ThisObject.Company Then
				Cancel = True;
				MessageText = StrTemplate(
					R().Error_Store_Company_Row,
					QuerySelection.Store,
					ThisObject.Company, 
					QuerySelection.LineNumber);
				CommonFunctionsClientServer.ShowUsersMessage(
					MessageText, 
					"Object.ItemList[" + (QuerySelection.LineNumber - 1) + "].Store", 
					"Object.ItemList");
			EndIf;
		EndDo;
	EndIf;
EndProcedure
