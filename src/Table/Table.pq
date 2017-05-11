section Table;
///////////////////////// 
// Table               //
/////////////////////////

shared Table.AddBlankRow = (table as table) => Table.Combine({table, Table.FromRecords({[]})});
// Transforms a column's value into its nested value -- if it eventually finds only one. Consider the following column:
//  MyCol
//  -----
//  "a"
//  {{{"b"}}}
//  Table.FromRecords({[MyCol=Table.FromRecords({[col=2]})})
//  {}
//
// Table.DrillColumn(table, "MyCol") will convert it to
//
//  MyCol
//  -----
//  "a"
//  "b"
//  2
//  null
shared Table.DrillIntoColumn = (table as table, columnName as text) =>
      let
          FindValue = (value as any) => 
            if value is list then
               if List.Count(value) = 1 then @FindValue(List.First(value)) 
               else if List.Count(value) = 0 then null
               else error "Couldn't find single value"
            else if value is table then
               if Table.RowCount(value) = 1 then @FindValue(List.First(Table.ToColumns(value)))
                                        else if Table.RowCount(value) = 0 then null 
               else error "Couldn't find single value"
            else  value,
          Result = Table.TransformColumns(table, {{columnName, FindValue}})
      in
         Result;
    
shared Table.EnterDataFormula = 
    Document(
        "Table.EnterDataFormula",
        "Convert a table into a formula that's compatible with the Enter Data UI. This function returns an expression you can copy and paste to editthe " &
            " table using Enter Data. Paste the formula, then click the gear icon next to the step name. This is an easy way to allow people to customize a table you've queried",
        {[ 
            Description = "Simple table", 
            Code = "Web.Page(Web.Contents(""https://en.wikipedia.org/wiki/List_of_Super_Bowl_champions"")){3}[Data]", 
            Result = "Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText(""jVVtb9s2EP4rRD4aRqI3S9TH2Gm7ZWkb1MGGom6Aq83IhBkyoOik2a8fT6Ski6Fu+yDdWea9Pffc8du3M342P7uVzrU/jrbZs7UTQgnb+q+lfzL/nFeLxIu0ror55pglWcK8viA6J3o96vVwJksSqvNRT5Ognn2fh1yuQClo2cq8/DCvmMbCPzmmUWaLkEYyn2GkNIhFEFUQvBN1FkQexGI2uP8kXtg73SjQO3YLzkrjMEgRn/NFEmrlpL66JLmnRM+JXhC9IvWR82lxWqvQz8KypTV6a9pYJxZ5nlex1mpMg5dEp98p5OR7TWEmqaYLkgY2eQ2avbegt7LdGlbUof1dApgLz/MASQCcF0EEpH3wDuJiNkfXWUAabT9YITRbwqvHeXsIPovBZ4S5jDWl3kdZjbqHfBbKmXUkGd1iA78ae2AfJGg36ZRH46QzTqKIrtLR1Wc4IA82FzemZZe68cRv2ReQu5Bs3vO/7JOt5kixEt886d45Vp1kg8u/oN1L3Tij2Rexaw9ST3qqAj95FIGmPFC4Jhl+lPAo2ZVRT/vgKeuHoeg9pWT2MqLnhCDkO6ccROSWoJx8NFZsLn7XO48pPBklcQCV6yNmdDJKPrbJj+LIejol9UmUj1Jr0RoH7E/pQWnQc9LPXNJ7ronngEkVyFaVszHh48MDKMOWUqlJN3VCZoDAUxMY6pwkiIASCmwu1u6c3ZijRDY8tpFeHQh5nIUq0r4O3Iotw//WApxTgnm5h5fDhHW3DGdhKDtRBOuMdsNHfhZDy7vCYoEdo8dhzkghePQP0C3uT+le2WovxUOfQfqmieX8Hkeuvh8M/eEtNB5XAXbShoesk3JM93YvFewE0hPYO2g8ejHbjHaExxEkha6kXzdag5M+oG5ATRuS9nF+UukKrGeqBr9ftNuHmT3xgDs6LKZ4BaR0g1wL1xdKAUaK3w+n7+DxCbo1tjxut6CFsFNGuAXehvhslfC9YGuQejIOjslogkv4SgrfgNUebDOWk77hNh1f/OfS+RXmx+o9qK3R0zZ8jHIncA5bIdiddPCL8/VpDCv/Nh5nD/jO460mrPBSD1Hw10qJZ9Fdsf5qexmi4IOuUxzXT5uLy8HgSjhrpGM30vyP09f+PmmNfvYLQLBraI5g/9voN3NscS3fiZ/wbzG+/wM="", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [Appearances = _t, Team = _t, Wins = _t, Losses = _t, Winning 
percentage = _t, Season(s) = _t])"
        ]},
        (table as table) =>
            let
                Encoded = Table.JsonEncode(table),
                ColumnMeta= "[" & Text.Range(List.Accumulate(Table.ColumnNames(table), "", (state, current) => state & ", " & current & " = _t"), 2) & "]",
                Text = 
                    "Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText(""" & Encoded & """, BinaryEncoding.Base64), Compression.Deflate))," & 
                    " let _t = ((type text) meta [Serialized.Text = true]) in type table " & ColumnMeta & ")"
            in
                Text
    );
// if fieldNames aren't specified, use the field names from the first row of the column.

// Perform a cross join of lists. Example usage:
// Table.FromListCrossJoin({ {ColorsTable[ColorName], "Color"}, {NumbersTable[Number], "Number"}})
// Will give me a new table with two columns, "Color" and "Number" which contains one row for each possible
// combination of colors and numbers
// Table.FromListCrossJoin({{"Red", "Blue"}, "Color"}, {{1,2,3}, "Number"}}) = 
//    Table.FromRecords({[Color="Red", Number=1],[Color="Red", Number = 2],[Color="Red", Number = 3],[Color="Blue", Number=1],[Color="Blue", Number=2],[Color="Blue", Number=3]})
shared Table.FromListCrossJoin = (listColumnNamePairs as any) =>
      let 
       remainingPairs = List.Skip(listColumnNamePairs, 1),
       current = List.First(listColumnNamePairs),
       theList = List.First(current),
       columnName = List.First(List.Skip(current),1),
       firstTable = Table.FromList(theList, null, {columnName}),
       doStuff = (table as table, remainingPairs as list) =>
          if List.Count(remainingPairs) <= 0 then table else
          let 
             current = List.First(remainingPairs),
             theList = List.First(current),
             columnName = List.First(List.Skip(current), 1),
             nextTable = Table.ExpandListColumn(Table.AddColumn(table, columnName, each theList), columnName)
          in @doStuff(nextTable, List.Skip(remainingPairs, 1)),
       Result = doStuff(firstTable, remainingPairs)
   in
       Result;
shared Table.JsonDecode = (encoded as text) =>
    let
        Decompressed = Binary.Decompress(Binary.FromText(encoded, BinaryEncoding.Base64), Compression.Deflate),
        Decoded = Table.FromRows(Json.Document(Decompressed), let _t = ((type text) meta [Serialized.Text = true]) in type table [Name = _t, Number = _t])
    in
        Decoded;
shared Table.JsonEncode = (table as table) =>
    let
        Rows = Table.ToRows(table),
        Json = Json.FromValue(Rows),
        Compressed = Binary.Compress(Json, Compression.Deflate),
        Encoded = Binary.ToText(Compressed, BinaryEncoding.Base64)
    in
        Encoded;
// Replaces a value if it matches a predicate
shared Table.ReplaceValueIf = (table as table, replaceIf as function, after as any, columnNameOrList as any) => 
    Table.ReplaceValue(table, null,after, (text, old, new)=>if replaceIf(text) then new else text, if columnNameOrList is list then columnNameOrList else {columnNameOrList});
// Splits camelCased and PascalCased column names. 
shared Table.SplitColumnNames = (table as table) => Table.RenameColumns(table, List.Transform(Table.ColumnNames(table), each {_, Text.SplitCamelCase(_)}));
// Splits camelCased and PascalCased text in a column. 
shared Table.SplitColumnText = (table as table, columns as list) => if List.Count(columns) = 0 then table else Table.TransformColumns(@Table.SplitColumnText(table, List.Skip(columns, 1)), {{List.First(columns), Text.SplitCamelCase}});
shared Table.TransformColumn = (table as table, column as text, transform as function) => Table.TransformColumns(table, {{column, transform}});
shared Table.RenameColumn = (table as table, column as text, newName as text) => Table.RenameColumns(table, {{column, newName}});
shared Table.RenameAndTransformColumn = (table, currentName as text, newName as text, transform as function) => Table.TransformColumn(Table.RenameColumns(table, {currentName, newName}), newName, transform);


///////////////////////// 
// Dependencies        //
/////////////////////////

Document = (name as text, description as text, valueOrExample as any, optional valueIfExample as any) =>
    let
        value = if valueIfExample is null then valueOrExample else valueIfExample,
        examples = if valueIfExample is null then {} else valueOrExample
    in
        Value.ReplaceType(value, Value.Type(value) meta [
            Documentation.Name = name, 
            Documentation.Description = description,  
            // [Description = "", Code="", Result =""]
            Documentation.Examples = examples
        ]);
Text.Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
Text.IsUpperCase = (text as text) => List.AllTrue(List.Transform(Text.ToList(text), (letter)=>Text.Contains(Text.Alphabet, letter) and letter = Text.Upper(letter)));
Text.SplitCamelCase = (text as nullable text) => if text is null then null else List.Accumulate(Text.ToList(text),"", (state, current) => 
   let
      PreviousLetter = Text.End(state, 1),
      Ignore = (text as text) => text = " " or text = "."
   in 
      state & 
      (if 
         not Text.IsUpperCase(PreviousLetter) and 
         not Ignore(PreviousLetter) and 
         not Ignore(current) and 
         Text.IsUpperCase(current) 
       then 
         " " else "" ) & 
      current);