// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branch_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BranchListState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchListState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BranchListState()';
}


}

/// @nodoc
class $BranchListStateCopyWith<$Res>  {
$BranchListStateCopyWith(BranchListState _, $Res Function(BranchListState) __);
}



/// @nodoc


class BranchListLoading implements BranchListState {
  const BranchListLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchListLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BranchListState.loading()';
}


}




/// @nodoc


class BranchListLoaded implements BranchListState {
  const BranchListLoaded({required final  List<BranchInfo> branches, required final  List<BranchInfo> filteredBranches, required this.currentBranch, required this.searchQuery, required this.selectedBranch, required this.selectedMode, required final  List<WorktreeMode> availableModes}): _branches = branches,_filteredBranches = filteredBranches,_availableModes = availableModes;
  

 final  List<BranchInfo> _branches;
 List<BranchInfo> get branches {
  if (_branches is EqualUnmodifiableListView) return _branches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_branches);
}

 final  List<BranchInfo> _filteredBranches;
 List<BranchInfo> get filteredBranches {
  if (_filteredBranches is EqualUnmodifiableListView) return _filteredBranches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_filteredBranches);
}

 final  String? currentBranch;
 final  String searchQuery;
 final  BranchInfo? selectedBranch;
 final  WorktreeMode? selectedMode;
 final  List<WorktreeMode> _availableModes;
 List<WorktreeMode> get availableModes {
  if (_availableModes is EqualUnmodifiableListView) return _availableModes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableModes);
}


/// Create a copy of BranchListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchListLoadedCopyWith<BranchListLoaded> get copyWith => _$BranchListLoadedCopyWithImpl<BranchListLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchListLoaded&&const DeepCollectionEquality().equals(other._branches, _branches)&&const DeepCollectionEquality().equals(other._filteredBranches, _filteredBranches)&&(identical(other.currentBranch, currentBranch) || other.currentBranch == currentBranch)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.selectedBranch, selectedBranch) || other.selectedBranch == selectedBranch)&&(identical(other.selectedMode, selectedMode) || other.selectedMode == selectedMode)&&const DeepCollectionEquality().equals(other._availableModes, _availableModes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_branches),const DeepCollectionEquality().hash(_filteredBranches),currentBranch,searchQuery,selectedBranch,selectedMode,const DeepCollectionEquality().hash(_availableModes));

@override
String toString() {
  return 'BranchListState.loaded(branches: $branches, filteredBranches: $filteredBranches, currentBranch: $currentBranch, searchQuery: $searchQuery, selectedBranch: $selectedBranch, selectedMode: $selectedMode, availableModes: $availableModes)';
}


}

/// @nodoc
abstract mixin class $BranchListLoadedCopyWith<$Res> implements $BranchListStateCopyWith<$Res> {
  factory $BranchListLoadedCopyWith(BranchListLoaded value, $Res Function(BranchListLoaded) _then) = _$BranchListLoadedCopyWithImpl;
@useResult
$Res call({
 List<BranchInfo> branches, List<BranchInfo> filteredBranches, String? currentBranch, String searchQuery, BranchInfo? selectedBranch, WorktreeMode? selectedMode, List<WorktreeMode> availableModes
});


$BranchInfoCopyWith<$Res>? get selectedBranch;

}
/// @nodoc
class _$BranchListLoadedCopyWithImpl<$Res>
    implements $BranchListLoadedCopyWith<$Res> {
  _$BranchListLoadedCopyWithImpl(this._self, this._then);

  final BranchListLoaded _self;
  final $Res Function(BranchListLoaded) _then;

/// Create a copy of BranchListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? branches = null,Object? filteredBranches = null,Object? currentBranch = freezed,Object? searchQuery = null,Object? selectedBranch = freezed,Object? selectedMode = freezed,Object? availableModes = null,}) {
  return _then(BranchListLoaded(
branches: null == branches ? _self._branches : branches // ignore: cast_nullable_to_non_nullable
as List<BranchInfo>,filteredBranches: null == filteredBranches ? _self._filteredBranches : filteredBranches // ignore: cast_nullable_to_non_nullable
as List<BranchInfo>,currentBranch: freezed == currentBranch ? _self.currentBranch : currentBranch // ignore: cast_nullable_to_non_nullable
as String?,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,selectedBranch: freezed == selectedBranch ? _self.selectedBranch : selectedBranch // ignore: cast_nullable_to_non_nullable
as BranchInfo?,selectedMode: freezed == selectedMode ? _self.selectedMode : selectedMode // ignore: cast_nullable_to_non_nullable
as WorktreeMode?,availableModes: null == availableModes ? _self._availableModes : availableModes // ignore: cast_nullable_to_non_nullable
as List<WorktreeMode>,
  ));
}

/// Create a copy of BranchListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BranchInfoCopyWith<$Res>? get selectedBranch {
    if (_self.selectedBranch == null) {
    return null;
  }

  return $BranchInfoCopyWith<$Res>(_self.selectedBranch!, (value) {
    return _then(_self.copyWith(selectedBranch: value));
  });
}
}

/// @nodoc


class BranchListError implements BranchListState {
  const BranchListError({required this.message});
  

 final  String message;

/// Create a copy of BranchListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchListErrorCopyWith<BranchListError> get copyWith => _$BranchListErrorCopyWithImpl<BranchListError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchListError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'BranchListState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $BranchListErrorCopyWith<$Res> implements $BranchListStateCopyWith<$Res> {
  factory $BranchListErrorCopyWith(BranchListError value, $Res Function(BranchListError) _then) = _$BranchListErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$BranchListErrorCopyWithImpl<$Res>
    implements $BranchListErrorCopyWith<$Res> {
  _$BranchListErrorCopyWithImpl(this._self, this._then);

  final BranchListError _self;
  final $Res Function(BranchListError) _then;

/// Create a copy of BranchListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(BranchListError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
