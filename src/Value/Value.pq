section Value;

///////////////////////// 
// Value               //
/////////////////////////
shared Value.TypeText = (value as any) => 
    if value is binary then "binary" else
    if value is date then "date" else
    if value is datetime then "datetime" else
    if value is datetimezone then "datetimezone" else
    if value is duration then "duration" else
    if value is function then "function" else
    if value is list then "list" else
    if value is logical then "logical" else
    if value is none then "none" else
    if value is null then "null" else
    if value is number then "number" else
    if value is record then "record" else
    if value is table then "table" else
    if value is text then "text" else
    if value is time then "time" else
    if value is type then "type" else
    if value is any then "any"
    else error "unknown -- not a primitive type!";

shared Value.ToText =
(Val as any, optional RecursTypes as logical) as text =>
let
    RecursTypes = if (RecursTypes<>null) then RecursTypes else false,
    Tried = (try Val),
    Value = if Tried[HasError] then Tried[Error] else Tried[Value],
/*
    DurationVals = {Duration.Days, Duration.Hours, Duration.Minutes, Duration.Seconds},
    DateVals = {Date.Year, Date.Month, Date.Day},
    TimeVals = {Time.Hour, Time.Minute, Time.Second},
    ZoneVals = {DateTimeZone.ZoneHours, DateTimeZone.ZoneMinutes},
    GetNumbers = (vals as list, obj as any) as text => Text.Combine(List.Transform(vals, each Number.ToText(Function.Invoke(_, {obj}))), ","),
*/
    CaseValues = {
    //{ (x)=> (try x)[HasError], "error " & @Value.ToText((try Value)[Error], RecursTypes) },
    { (x)=> Value.Is(x, type type), Type.ToText(Value, RecursTypes) },
    { (x)=> Value.Is(x, type function),
        let
            Type = Value.Type(Value),
            Params = Type.FunctionParameters(Type),
            Reqd = Type.FunctionRequiredParameters(Type),
            Ret = Type.FunctionReturn(Type)
        in
        "function (" &
        Record.TransformJoin(Params, (k,v) =>
            (if List.PositionOf(Record.FieldNames(Params), k) >= Reqd then "optional " else "") &
            k & " as " & @Value.ToText(v, RecursTypes)
        )
        & ") as " & @Value.ToText(Ret, RecursTypes)
    },
    { (x)=> Value.Is(x, type table), "#table(" & @Value.ToText(Table.ColumnNames(Value), RecursTypes) & ", " & @Value.ToText(Table.ToRows(Value), RecursTypes) & ")"},
    { (x)=> Value.Is(x, type record), "[" &
        Record.TransformJoin(Value, (k,v) => k & "=" & @Value.ToText(v, RecursTypes))
    & "]" },
    { (x)=> Value.Is(x, type list), "{" & Text.Combine(List.Transform(Value, each @Value.ToText(_, RecursTypes)), ", ") & "}" },
    { (x)=> x = null, "null" },
/*
    { (x)=> Value.Is(x, type text), """" & Value & """" },
    { (x)=> Value.Is(x, type binary), "#binary(""" & Binary.ToText(Value) & """)" },
    { (x)=> Value.Is(x, type date), "#date(" & GetNumbers(DateVals, Value) & ")" },    //alt: Date.ToText(Value)
    { (x)=> Value.Is(x, type time), "#time(" & GetNumbers(TimeVals, Value) & ")" },    //alt: Time.ToText(Value)
    { (x)=> Value.Is(x, type datetime),
        let
            Date = DateTime.Date(Value),
            Time = DateTime.Time(Value)
        in
            "#datetime(" & GetNumbers(DateVals, Date) & ", " & GetNumbers(TimeVals, Time) & ")"
    },    //alt: DateTime.ToText(Value)
    { (x)=> Value.Is(x, type datetimezone),
        let
            DateTime = DateTimeZone.RemoveZone(Value),
            Date = DateTime.Date(DateTime),
            Time = DateTime.Time(DateTime)
        in
            "#datetimezone(" & GetNumbers(DateVals, Date) & ", " & GetNumbers(TimeVals, Time) & ", " & GetNumbers(ZoneVals, Value) & ")"
    },    //alt: DateTimeZone.ToText(Value)
    { (x)=> Value.Is(x, type duration), "#duration(" & GetNumbers(DurationVals, Value) & ")" },    //alt: Duration.ToText(Value)
//    { (x)=> Value.Is(x, type logical), Logical.ToText(Value) },
//    { (x)=> Value.Is(x, type number), Number.ToText(Value) },
    { (x)=> true, Text.From(Value) }
*/
    { (x)=> true, Expression.Constant(Value) }
    },
    Return = List.First(List.Select(CaseValues, each _{0}(Value))){1}
in Return;

shared Value.TypeToText = 
    (Value as any, optional Recurs as logical) as text =>
    let
        Recurs = if (Recurs<>null) then Recurs else false,
        Type = Value.Type(Value),
        ToText = if Value.Is(Value, type type) and Recurs then
            "type " & Type.ToText(Value, Recurs)
        else
            Type.ToText(Type, Recurs),
        Return = ToText
    in Return;

shared Value.WaitFor =
//author: Curt Hagenlocher https://gist.github.com/CurtHagenlocher/68ac18caa0a17667c805
(producer as function, interval as function, optional count as number) as any =>
let
	list = List.Generate(
		//start: first try, no result
		() => {0, null},
		//condition: stop if we have the result (try count null'd) or we've exceeded the max tries
		(state) => state{0} <> null and (count = null or state{0} < count),
		//next: stop try tally if we have our result, otherwise check again and tally a try
		(state) => if state{1} <> null
			then {null, state{1}}
			else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
		//transformer: only return the result, not try tally
		(state) => state{1})
in
	List.Last(list);
///////////////////////// 
// Dependencies        //
/////////////////////////

Type.ToText =
(Type as any, optional Recurs as logical) as text =>
let
    Recurs = if (Recurs<>null) then Recurs else false,

    CaseValues = {
    { (x)=> (try x)[HasError], "error" },
    { (x)=> Type.Is(x, type type), "type"},    //if Recurs then  else 
    { (x)=> Type.Is(x, type function), "function"},
    { (x)=> Type.Is(x, type table), if Recurs then "table " & @Type.ToText(Type.TableRow(NonNull), Recurs) else "table"},
    { (x)=> Type.Is(x, type record), if Recurs then
        let
            Record = Type.RecordFields(NonNull)
        in "[" & Record.TransformJoin(Record, (k,v) =>
            (if v[Optional] then "optional " else "") & Expression.Identifier(k) & " = " & @Type.ToText(v[Type], Recurs)
        ) & "]"
    else "record"},
    { (x)=> Type.Is(x, type list), if Recurs then "{" & @Type.ToText(Type.ListItem(NonNull), Recurs) & "}" else "list"},
    { (x)=> Type.Is(x, type binary), "binary"},
    { (x)=> Type.Is(x, type logical), "logical"},
    { (x)=> Type.Is(x, type number), "number"},
    { (x)=> Type.Is(x, type text), "text"},
    { (x)=> Type.Is(x, type date), "date"},
    { (x)=> Type.Is(x, type time), "time"},
    { (x)=> Type.Is(x, type datetime), "datetime"},
    { (x)=> Type.Is(x, type datetimezone), "datetimezone"},
    { (x)=> Type.Is(x, type duration), "duration"},
    { (x)=> Type.Is(type anynonnull, x), "anynonnull"},
    { (x)=> Type.Is(type null, x), "null"},
    { (x)=> Type.Is(None.Type, x), "none"},
//    { (x)=> Type.Is(type any, x), "any"},
    { (x)=> true, "?"}
    },
    NonNull = Type.NonNullable(Type),
    Return = if Type.Is(type any, Type) then "any"
    else (if Type.IsNullable(Type) then "nullable " else "")
    & List.First(List.Select(CaseValues, each _{0}(NonNull))){1}
in Return;

Record.TransformJoin = 
(Rec as record, Lambda as function, optional Delimiter as text) as text =>
let
    Delimiter = if (Delimiter<>null) then Delimiter else ", ",

    Keys = Record.FieldNames(Rec),
    Transformed = List.Transform(Keys, each Lambda(_, Record.Field(Rec,_))),
    Combined = Text.Combine(Transformed, Delimiter),

    Return = Combined
in
    Return;