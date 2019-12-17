import 'package:crud_generator/crud_generator.dart';

class GenerateBlocClass extends GenerateEntityClassAbstract {
  GenerateBlocClass(String name)
      : super(name, classSuffix: 'Bloc', parentClass: 'BlocBase') {
    generateClass.writeln('String _documentId;');
  }

  @override
  addImports() {
    importEntity();
    importGenerate('repository');
    generateClass.writeln('import \'package:bloc_pattern/bloc_pattern.dart\';');
    generateClass.writeln('import \'package:rxdart/rxdart.dart\';');
  }

  _constructor() {
    generateClass.writeln('$name() {');
    fields.forEach((field, type) {
      generateClass.writeln(
          '_$field' + 'Controller.listen((value) => _$field = value);');
    });
    generateClass.writeln('}');
  }

  @override
  generateFieldDeclaration(type, name, {bool persistField: false}) {
    generateClass.writeln('$type ' + (persistField ? '_' : '') + '$name;');
  }

  _gettters() {
    fields.forEach((field, type) {
      generateClass
          .writeln('var _$field' + 'Controller = BehaviorSubject<$type>();');
      generateClass.writeln(
          'Stream<$type> get $field => _$field' + 'Controller.stream;');
    });
  }

  _setters() {
    fields.forEach((field, type) {
      generateClass.writeln('void set$field($type value) => _$field' +
          'Controller.sink.add(value);');
    });
  }

  _setEntity() {
    generateClass.writeln('void set$entityClass($entityClassInstance) {');
    generateClass.writeln('_documentId = $entityInstance.documentId();');
    generateClass.writeln('}');
  }

  _insertOrUpdate() {
    generateClass.writeln('void insertOrUpdate() {');
    generateClass.writeln('var $entityInstance = $entityClass()');
    fields.forEach((field, type) {
        generateClass.writeln('..$field = _$field');
    });
    generateClass.writeln(';');
    generateClass.writeln('if (_documentId?.isEmpty ?? true) {');
    generateClass.writeln('_repository.add($entityInstance);');
    generateClass.writeln('} else {');
    generateClass.writeln('_repository.update(_documentId, $entityInstance);');
    generateClass.writeln('}');
    generateClass.writeln('}');
  }

  _repository() {
    generateClass.writeln('var _repository = $classPrefix'+'Repository();');
  }

  _dispose() {
    generateClass.writeln('void dispose() {');
    fields.forEach((field, type) {
      generateClass.writeln('_$field'+'Controller.close();');
    });
    generateClass.writeln('super.dispose();');
    generateClass.writeln('}');
  }

  @override
  String build() {
    this._constructor();
    this._repository();
    this._setEntity();
    this._setters();
    this._gettters();
    this._insertOrUpdate();    
    this._dispose();
    return super.build();
  }
}
