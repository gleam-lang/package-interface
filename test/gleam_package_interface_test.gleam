import birdie
import glam/doc.{type Document}
import gleam/dict.{type Dict}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/package_interface.{
  type Constant, type Deprecation, type Function, type Implementations,
  type Module, type Package, type Parameter, type Type, type TypeAlias,
  type TypeConstructor, type TypeDefinition, Constant, Deprecation, Fn, Function,
  Implementations, Module, Named, Package, Parameter, Tuple, TypeAlias,
  TypeConstructor, TypeDefinition, Variable,
}
import gleam/string
import gleeunit
import simplifile

pub fn main() {
  gleeunit.main()
}

pub fn decoding_a_module_interface_test() {
  let assert Ok(raw_package) = simplifile.read("./priv/interface.json")
  let assert Ok(package) = json.decode(raw_package, package_interface.decoder)

  pretty_package(package)
  |> birdie.snap(title: "Decoding a module interface")
}

// --- PRETTY PRINTING THE PACKAGE ---------------------------------------------
// We use a custom pretty printer to make reviewing the snapshots easier.

fn pretty_package(package: Package) -> String {
  package_to_doc(package)
  |> doc.to_string(80)
}

fn package_to_doc(package: Package) -> Document {
  let Package(
    name: name,
    version: version,
    gleam_version_constraint: gleam_version_constraint,
    modules: modules,
  ) = package
  constructor("Package", [
    #("name", string(name)),
    #("version", string(version)),
    #("gleam_version_contraint", optional(gleam_version_constraint, string)),
    #("modules", sorted_dict(modules, module_to_doc)),
  ])
}

fn module_to_doc(module: Module) -> Document {
  let Module(
    documentation: documentation,
    type_aliases: type_aliases,
    constants: constants,
    functions: functions,
    types: types,
  ) = module

  constructor("Module", [
    #("documentation", list(list.map(documentation, string))),
    #("type_aliases", sorted_dict(type_aliases, type_alias_to_doc)),
    #("constants", sorted_dict(constants, constant_to_doc)),
    #("functions", sorted_dict(functions, function_to_doc)),
    #("types", sorted_dict(types, type_definition_to_doc)),
  ])
}

fn type_alias_to_doc(type_alias: TypeAlias) -> Document {
  let TypeAlias(
    alias: alias,
    deprecation: deprecation,
    documentation: documentation,
    parameters: parameters,
  ) = type_alias

  constructor("TypeAlias", [
    #("alias", type_to_doc(alias)),
    #("deprecation", optional(deprecation, deprecation_to_doc)),
    #("documentation", optional(documentation, string)),
    #("parameters", int(parameters)),
  ])
}

fn deprecation_to_doc(deprecation: Deprecation) -> Document {
  let Deprecation(message: message) = deprecation
  constructor("Deprecation", [#("message", string(message))])
}

fn constant_to_doc(constant: Constant) -> Document {
  let Constant(
    deprecation: deprecation,
    documentation: documentation,
    implementations: implementations,
    type_: type_,
  ) = constant

  constructor("Constant", [
    #("deprecation", optional(deprecation, deprecation_to_doc)),
    #("documentation", optional(documentation, string)),
    #("implementations", implementations_to_doc(implementations)),
    #("type_", type_to_doc(type_)),
  ])
}

fn function_to_doc(function: Function) -> Document {
  let Function(
    deprecation: deprecation,
    documentation: documentation,
    implementations: implementations,
    parameters: parameters,
    return: return,
  ) = function

  constructor("Function", [
    #("deprecation", optional(deprecation, deprecation_to_doc)),
    #("documentation", optional(documentation, string)),
    #("implementations", implementations_to_doc(implementations)),
    #("parameters", list(list.map(parameters, parameter_to_doc))),
    #("return", type_to_doc(return)),
  ])
}

fn type_definition_to_doc(type_definition: TypeDefinition) -> Document {
  let TypeDefinition(
    constructors: constructors,
    deprecation: deprecation,
    documentation: documentation,
    parameters: parameters,
  ) = type_definition

  constructor("TypeDefinition", [
    #("constructors", list(list.map(constructors, constructor_to_doc))),
    #("deprecation", optional(deprecation, deprecation_to_doc)),
    #("documentation", optional(documentation, string)),
    #("parameters", int(parameters)),
  ])
}

fn constructor_to_doc(constructor_: TypeConstructor) -> Document {
  let TypeConstructor(
    documentation: documentation,
    name: name,
    parameters: parameters,
  ) = constructor_

  constructor("TypeConstructor", [
    #("documentation", optional(documentation, string)),
    #("name", string(name)),
    #("parameters", list(list.map(parameters, parameter_to_doc))),
  ])
}

fn implementations_to_doc(implementations: Implementations) -> Document {
  let Implementations(
    gleam: gleam,
    uses_erlang_externals: uses_erlang_externals,
    uses_javascript_externals: uses_javascript_externals,
  ) = implementations

  constructor("Implementations", [
    #("gleam", bool(gleam)),
    #("uses_erlang_externals", bool(uses_erlang_externals)),
    #("uses_javascript_externals", bool(uses_javascript_externals)),
  ])
}

fn parameter_to_doc(parameter: Parameter) -> Document {
  let Parameter(label: label, type_: type_) = parameter
  constructor("Parameter", [
    #("label", optional(label, string)),
    #("type", type_to_doc(type_)),
  ])
}

fn type_to_doc(type_: Type) -> Document {
  case type_ {
    Fn(parameters: parameters, return: return) ->
      constructor("Fn", [
        #("parameters", list(list.map(parameters, type_to_doc))),
        #("return", type_to_doc(return)),
      ])

    Tuple(elements: elements) ->
      constructor("Tuple", [
        #("elements", list(list.map(elements, type_to_doc))),
      ])

    Variable(id: id) -> constructor("Variable", [#("id", int(id))])

    Named(package: package, module: module, name: name, parameters: parameters) ->
      constructor("Named", [
        #("package", string(package)),
        #("module", string(module)),
        #("name", string(name)),
        #("parameters", list(list.map(parameters, type_to_doc))),
      ])
  }
}

fn sorted_dict(
  dict: Dict(String, a),
  with to_doc: fn(a) -> Document,
) -> Document {
  dict.to_list(dict)
  |> list.sort(fn(one, other) { string.compare(one.0, other.0) })
  |> list.map(fn(entry) {
    let #(name, value) = entry
    doc.concat([
      doc.from_string(name <> ": "),
      to_doc(value)
        |> doc.nest(by: 2),
    ])
  })
  |> parenthesise("{", "}", _)
}

fn constructor(
  named name: String,
  args args: List(#(String, Document)),
) -> Document {
  let args =
    list.map(args, fn(pair) {
      let #(name, arg) = pair
      [doc.from_string(name <> ": "), arg]
      |> doc.concat
    })

  [doc.from_string(name), parenthesise("(", ")", args)]
  |> doc.concat
}

fn list(of docs: List(Document)) -> Document {
  parenthesise("[", "]", docs)
}

fn optional(value: Option(a), fun: fn(a) -> Document) -> Document {
  case value {
    Some(a) -> constructor("Some", [#("item", fun(a))])
    None -> constructor("None", [])
  }
}

fn bool(value: Bool) -> Document {
  case value {
    True -> doc.from_string("True")
    False -> doc.from_string("False")
  }
}

fn int(value: Int) -> Document {
  doc.from_string(int.to_string(value))
}

fn string(value: String) -> Document {
  doc.from_string("\"" <> value <> "\"")
}

fn parenthesise(open: String, close: String, docs: List(Document)) -> Document {
  case docs {
    [] -> doc.from_string(open <> close)
    [_, ..] ->
      [
        doc.from_string(open),
        doc.nest(doc.break("", ""), by: 2),
        docs
          |> doc.join(with: doc.break(", ", ","))
          |> doc.nest(by: 2),
        doc.break("", ","),
        doc.from_string(close),
      ]
      |> doc.concat
      |> doc.group
  }
}
