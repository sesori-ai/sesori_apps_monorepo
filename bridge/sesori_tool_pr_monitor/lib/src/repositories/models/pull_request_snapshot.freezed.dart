// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PullRequestSnapshot {

 String get title; String get url; PullRequestState get state; PullRequestMergeable get mergeable; String get headSha;/// Empty when the head commit has no CI at all.
 List<PullRequestCheck> get checks;/// The latest submitted review per reviewer.
 List<PullRequestReview> get reviews;/// Reviews with a non-blank body, plus changes-requested reviews that have
/// no inline comments.
 List<PullRequestComment> get reviewSummaries;/// Requested reviewers (user and bot logins, team slugs) who have not
/// reviewed yet.
 List<String> get pendingReviewers; List<PullRequestReviewThread> get reviewThreads;/// GitHub's issue-comment count minus the agent replies in the fetched
/// window, never below zero.
 int get issueCommentsTotal;/// The latest 100 issue comments, agent replies included.
 List<PullRequestComment> get issueComments; List<String> get labels;
/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestSnapshotCopyWith<PullRequestSnapshot> get copyWith => _$PullRequestSnapshotCopyWithImpl<PullRequestSnapshot>(this as PullRequestSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestSnapshot&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.mergeable, _this.mergeable) || other.mergeable == _this.mergeable)&&(identical(other.headSha, _this.headSha) || other.headSha == _this.headSha)&&const DeepCollectionEquality().equals(other.checks, _this.checks)&&const DeepCollectionEquality().equals(other.reviews, _this.reviews)&&const DeepCollectionEquality().equals(other.reviewSummaries, _this.reviewSummaries)&&const DeepCollectionEquality().equals(other.pendingReviewers, _this.pendingReviewers)&&const DeepCollectionEquality().equals(other.reviewThreads, _this.reviewThreads)&&(identical(other.issueCommentsTotal, _this.issueCommentsTotal) || other.issueCommentsTotal == _this.issueCommentsTotal)&&const DeepCollectionEquality().equals(other.issueComments, _this.issueComments)&&const DeepCollectionEquality().equals(other.labels, _this.labels));
}


@override
int get hashCode {
  final _this = this as PullRequestSnapshot;
  return Object.hash(runtimeType,_this.title,_this.url,_this.state,_this.mergeable,_this.headSha,const DeepCollectionEquality().hash(_this.checks),const DeepCollectionEquality().hash(_this.reviews),const DeepCollectionEquality().hash(_this.reviewSummaries),const DeepCollectionEquality().hash(_this.pendingReviewers),const DeepCollectionEquality().hash(_this.reviewThreads),_this.issueCommentsTotal,const DeepCollectionEquality().hash(_this.issueComments),const DeepCollectionEquality().hash(_this.labels));
}

@override
String toString() {
  final _this = this as PullRequestSnapshot;
  return 'PullRequestSnapshot(title: ${_this.title}, url: ${_this.url}, state: ${_this.state}, mergeable: ${_this.mergeable}, headSha: ${_this.headSha}, checks: ${_this.checks}, reviews: ${_this.reviews}, reviewSummaries: ${_this.reviewSummaries}, pendingReviewers: ${_this.pendingReviewers}, reviewThreads: ${_this.reviewThreads}, issueCommentsTotal: ${_this.issueCommentsTotal}, issueComments: ${_this.issueComments}, labels: ${_this.labels})';
}


}

/// @nodoc
abstract mixin class $PullRequestSnapshotCopyWith<$Res>  {
  factory $PullRequestSnapshotCopyWith(PullRequestSnapshot value, $Res Function(PullRequestSnapshot) _then) = _$PullRequestSnapshotCopyWithImpl;
@useResult
$Res call({
 String title, String url, PullRequestState state, PullRequestMergeable mergeable, String headSha, List<PullRequestCheck> checks, List<PullRequestReview> reviews, List<PullRequestComment> reviewSummaries, List<String> pendingReviewers, List<PullRequestReviewThread> reviewThreads, int issueCommentsTotal, List<PullRequestComment> issueComments, List<String> labels
});




}
/// @nodoc
class _$PullRequestSnapshotCopyWithImpl<$Res>
    implements $PullRequestSnapshotCopyWith<$Res> {
  _$PullRequestSnapshotCopyWithImpl(this._self, this._then);

  final PullRequestSnapshot _self;
  final $Res Function(PullRequestSnapshot) _then;

/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? url = null,Object? state = null,Object? mergeable = null,Object? headSha = null,Object? checks = null,Object? reviews = null,Object? reviewSummaries = null,Object? pendingReviewers = null,Object? reviewThreads = null,Object? issueCommentsTotal = null,Object? issueComments = null,Object? labels = null,}) {
  return _then(PullRequestSnapshot(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PullRequestState,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as PullRequestMergeable,headSha: null == headSha ? _self.headSha : headSha // ignore: cast_nullable_to_non_nullable
as String,checks: null == checks ? _self.checks : checks // ignore: cast_nullable_to_non_nullable
as List<PullRequestCheck>,reviews: null == reviews ? _self.reviews : reviews // ignore: cast_nullable_to_non_nullable
as List<PullRequestReview>,reviewSummaries: null == reviewSummaries ? _self.reviewSummaries : reviewSummaries // ignore: cast_nullable_to_non_nullable
as List<PullRequestComment>,pendingReviewers: null == pendingReviewers ? _self.pendingReviewers : pendingReviewers // ignore: cast_nullable_to_non_nullable
as List<String>,reviewThreads: null == reviewThreads ? _self.reviewThreads : reviewThreads // ignore: cast_nullable_to_non_nullable
as List<PullRequestReviewThread>,issueCommentsTotal: null == issueCommentsTotal ? _self.issueCommentsTotal : issueCommentsTotal // ignore: cast_nullable_to_non_nullable
as int,issueComments: null == issueComments ? _self.issueComments : issueComments // ignore: cast_nullable_to_non_nullable
as List<PullRequestComment>,labels: null == labels ? _self.labels : labels // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc


class _PullRequestSnapshot implements PullRequestSnapshot {
  const _PullRequestSnapshot({required this.title, required this.url, required this.state, required this.mergeable, required this.headSha, required  List<PullRequestCheck> checks, required  List<PullRequestReview> reviews, required  List<PullRequestComment> reviewSummaries, required  List<String> pendingReviewers, required  List<PullRequestReviewThread> reviewThreads, required this.issueCommentsTotal, required  List<PullRequestComment> issueComments, required  List<String> labels}): _checks = checks,_reviews = reviews,_reviewSummaries = reviewSummaries,_pendingReviewers = pendingReviewers,_reviewThreads = reviewThreads,_issueComments = issueComments,_labels = labels;
  

@override final  String title;
@override final  String url;
@override final  PullRequestState state;
@override final  PullRequestMergeable mergeable;
@override final  String headSha;
/// Empty when the head commit has no CI at all.
 final  List<PullRequestCheck> _checks;
/// Empty when the head commit has no CI at all.
@override List<PullRequestCheck> get checks {
  if (_checks is EqualUnmodifiableListView) return _checks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_checks);
}

/// The latest submitted review per reviewer.
 final  List<PullRequestReview> _reviews;
/// The latest submitted review per reviewer.
@override List<PullRequestReview> get reviews {
  if (_reviews is EqualUnmodifiableListView) return _reviews;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reviews);
}

/// Reviews with a non-blank body, plus changes-requested reviews that have
/// no inline comments.
 final  List<PullRequestComment> _reviewSummaries;
/// Reviews with a non-blank body, plus changes-requested reviews that have
/// no inline comments.
@override List<PullRequestComment> get reviewSummaries {
  if (_reviewSummaries is EqualUnmodifiableListView) return _reviewSummaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reviewSummaries);
}

/// Requested reviewers (user and bot logins, team slugs) who have not
/// reviewed yet.
 final  List<String> _pendingReviewers;
/// Requested reviewers (user and bot logins, team slugs) who have not
/// reviewed yet.
@override List<String> get pendingReviewers {
  if (_pendingReviewers is EqualUnmodifiableListView) return _pendingReviewers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingReviewers);
}

 final  List<PullRequestReviewThread> _reviewThreads;
@override List<PullRequestReviewThread> get reviewThreads {
  if (_reviewThreads is EqualUnmodifiableListView) return _reviewThreads;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reviewThreads);
}

/// GitHub's issue-comment count minus the agent replies in the fetched
/// window, never below zero.
@override final  int issueCommentsTotal;
/// The latest 100 issue comments, agent replies included.
 final  List<PullRequestComment> _issueComments;
/// The latest 100 issue comments, agent replies included.
@override List<PullRequestComment> get issueComments {
  if (_issueComments is EqualUnmodifiableListView) return _issueComments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_issueComments);
}

 final  List<String> _labels;
@override List<String> get labels {
  if (_labels is EqualUnmodifiableListView) return _labels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_labels);
}


/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestSnapshotCopyWith<_PullRequestSnapshot> get copyWith => __$PullRequestSnapshotCopyWithImpl<_PullRequestSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestSnapshot&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.state, state) || other.state == state)&&(identical(other.mergeable, mergeable) || other.mergeable == mergeable)&&(identical(other.headSha, headSha) || other.headSha == headSha)&&const DeepCollectionEquality().equals(other.checks, _checks)&&const DeepCollectionEquality().equals(other.reviews, _reviews)&&const DeepCollectionEquality().equals(other.reviewSummaries, _reviewSummaries)&&const DeepCollectionEquality().equals(other.pendingReviewers, _pendingReviewers)&&const DeepCollectionEquality().equals(other.reviewThreads, _reviewThreads)&&(identical(other.issueCommentsTotal, issueCommentsTotal) || other.issueCommentsTotal == issueCommentsTotal)&&const DeepCollectionEquality().equals(other.issueComments, _issueComments)&&const DeepCollectionEquality().equals(other.labels, _labels));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,url,state,mergeable,headSha,const DeepCollectionEquality().hash(_checks),const DeepCollectionEquality().hash(_reviews),const DeepCollectionEquality().hash(_reviewSummaries),const DeepCollectionEquality().hash(_pendingReviewers),const DeepCollectionEquality().hash(_reviewThreads),issueCommentsTotal,const DeepCollectionEquality().hash(_issueComments),const DeepCollectionEquality().hash(_labels));
}

@override
String toString() {
    return 'PullRequestSnapshot(title: $title, url: $url, state: $state, mergeable: $mergeable, headSha: $headSha, checks: $checks, reviews: $reviews, reviewSummaries: $reviewSummaries, pendingReviewers: $pendingReviewers, reviewThreads: $reviewThreads, issueCommentsTotal: $issueCommentsTotal, issueComments: $issueComments, labels: $labels)';
}


}

/// @nodoc
abstract mixin class _$PullRequestSnapshotCopyWith<$Res> implements $PullRequestSnapshotCopyWith<$Res> {
  factory _$PullRequestSnapshotCopyWith(_PullRequestSnapshot value, $Res Function(_PullRequestSnapshot) _then) = __$PullRequestSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String title, String url, PullRequestState state, PullRequestMergeable mergeable, String headSha, List<PullRequestCheck> checks, List<PullRequestReview> reviews, List<PullRequestComment> reviewSummaries, List<String> pendingReviewers, List<PullRequestReviewThread> reviewThreads, int issueCommentsTotal, List<PullRequestComment> issueComments, List<String> labels
});




}
/// @nodoc
class __$PullRequestSnapshotCopyWithImpl<$Res>
    implements _$PullRequestSnapshotCopyWith<$Res> {
  __$PullRequestSnapshotCopyWithImpl(this._self, this._then);

  final _PullRequestSnapshot _self;
  final $Res Function(_PullRequestSnapshot) _then;

/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? url = null,Object? state = null,Object? mergeable = null,Object? headSha = null,Object? checks = null,Object? reviews = null,Object? reviewSummaries = null,Object? pendingReviewers = null,Object? reviewThreads = null,Object? issueCommentsTotal = null,Object? issueComments = null,Object? labels = null,}) {
  return _then(_PullRequestSnapshot(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PullRequestState,mergeable: null == mergeable ? _self.mergeable : mergeable // ignore: cast_nullable_to_non_nullable
as PullRequestMergeable,headSha: null == headSha ? _self.headSha : headSha // ignore: cast_nullable_to_non_nullable
as String,checks: null == checks ? _self._checks : checks // ignore: cast_nullable_to_non_nullable
as List<PullRequestCheck>,reviews: null == reviews ? _self._reviews : reviews // ignore: cast_nullable_to_non_nullable
as List<PullRequestReview>,reviewSummaries: null == reviewSummaries ? _self._reviewSummaries : reviewSummaries // ignore: cast_nullable_to_non_nullable
as List<PullRequestComment>,pendingReviewers: null == pendingReviewers ? _self._pendingReviewers : pendingReviewers // ignore: cast_nullable_to_non_nullable
as List<String>,reviewThreads: null == reviewThreads ? _self._reviewThreads : reviewThreads // ignore: cast_nullable_to_non_nullable
as List<PullRequestReviewThread>,issueCommentsTotal: null == issueCommentsTotal ? _self.issueCommentsTotal : issueCommentsTotal // ignore: cast_nullable_to_non_nullable
as int,issueComments: null == issueComments ? _self._issueComments : issueComments // ignore: cast_nullable_to_non_nullable
as List<PullRequestComment>,labels: null == labels ? _self._labels : labels // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$PullRequestCheck {

 String get id; String get name; PullRequestCheckOutcome get outcome;
/// Create a copy of PullRequestCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestCheckCopyWith<PullRequestCheck> get copyWith => _$PullRequestCheckCopyWithImpl<PullRequestCheck>(this as PullRequestCheck, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestCheck;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestCheck&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome));
}


@override
int get hashCode {
  final _this = this as PullRequestCheck;
  return Object.hash(runtimeType,_this.id,_this.name,_this.outcome);
}

@override
String toString() {
  final _this = this as PullRequestCheck;
  return 'PullRequestCheck(id: ${_this.id}, name: ${_this.name}, outcome: ${_this.outcome})';
}


}

/// @nodoc
abstract mixin class $PullRequestCheckCopyWith<$Res>  {
  factory $PullRequestCheckCopyWith(PullRequestCheck value, $Res Function(PullRequestCheck) _then) = _$PullRequestCheckCopyWithImpl;
@useResult
$Res call({
 String id, String name, PullRequestCheckOutcome outcome
});




}
/// @nodoc
class _$PullRequestCheckCopyWithImpl<$Res>
    implements $PullRequestCheckCopyWith<$Res> {
  _$PullRequestCheckCopyWithImpl(this._self, this._then);

  final PullRequestCheck _self;
  final $Res Function(PullRequestCheck) _then;

/// Create a copy of PullRequestCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? outcome = null,}) {
  return _then(PullRequestCheck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as PullRequestCheckOutcome,
  ));
}

}



/// @nodoc


class _PullRequestCheck implements PullRequestCheck {
  const _PullRequestCheck({required this.id, required this.name, required this.outcome});
  

@override final  String id;
@override final  String name;
@override final  PullRequestCheckOutcome outcome;

/// Create a copy of PullRequestCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestCheckCopyWith<_PullRequestCheck> get copyWith => __$PullRequestCheckCopyWithImpl<_PullRequestCheck>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestCheck&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,outcome);
}

@override
String toString() {
    return 'PullRequestCheck(id: $id, name: $name, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class _$PullRequestCheckCopyWith<$Res> implements $PullRequestCheckCopyWith<$Res> {
  factory _$PullRequestCheckCopyWith(_PullRequestCheck value, $Res Function(_PullRequestCheck) _then) = __$PullRequestCheckCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PullRequestCheckOutcome outcome
});




}
/// @nodoc
class __$PullRequestCheckCopyWithImpl<$Res>
    implements _$PullRequestCheckCopyWith<$Res> {
  __$PullRequestCheckCopyWithImpl(this._self, this._then);

  final _PullRequestCheck _self;
  final $Res Function(_PullRequestCheck) _then;

/// Create a copy of PullRequestCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? outcome = null,}) {
  return _then(_PullRequestCheck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as PullRequestCheckOutcome,
  ));
}


}

/// @nodoc
mixin _$PullRequestReview {

 String get login; PullRequestReviewState get state; DateTime get submittedAt;
/// Create a copy of PullRequestReview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestReviewCopyWith<PullRequestReview> get copyWith => _$PullRequestReviewCopyWithImpl<PullRequestReview>(this as PullRequestReview, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestReview;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestReview&&(identical(other.login, _this.login) || other.login == _this.login)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.submittedAt, _this.submittedAt) || other.submittedAt == _this.submittedAt));
}


@override
int get hashCode {
  final _this = this as PullRequestReview;
  return Object.hash(runtimeType,_this.login,_this.state,_this.submittedAt);
}

@override
String toString() {
  final _this = this as PullRequestReview;
  return 'PullRequestReview(login: ${_this.login}, state: ${_this.state}, submittedAt: ${_this.submittedAt})';
}


}

/// @nodoc
abstract mixin class $PullRequestReviewCopyWith<$Res>  {
  factory $PullRequestReviewCopyWith(PullRequestReview value, $Res Function(PullRequestReview) _then) = _$PullRequestReviewCopyWithImpl;
@useResult
$Res call({
 String login, PullRequestReviewState state, DateTime submittedAt
});




}
/// @nodoc
class _$PullRequestReviewCopyWithImpl<$Res>
    implements $PullRequestReviewCopyWith<$Res> {
  _$PullRequestReviewCopyWithImpl(this._self, this._then);

  final PullRequestReview _self;
  final $Res Function(PullRequestReview) _then;

/// Create a copy of PullRequestReview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? login = null,Object? state = null,Object? submittedAt = null,}) {
  return _then(PullRequestReview(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PullRequestReviewState,submittedAt: null == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}



/// @nodoc


class _PullRequestReview implements PullRequestReview {
  const _PullRequestReview({required this.login, required this.state, required this.submittedAt});
  

@override final  String login;
@override final  PullRequestReviewState state;
@override final  DateTime submittedAt;

/// Create a copy of PullRequestReview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestReviewCopyWith<_PullRequestReview> get copyWith => __$PullRequestReviewCopyWithImpl<_PullRequestReview>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestReview&&(identical(other.login, login) || other.login == login)&&(identical(other.state, state) || other.state == state)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,login,state,submittedAt);
}

@override
String toString() {
    return 'PullRequestReview(login: $login, state: $state, submittedAt: $submittedAt)';
}


}

/// @nodoc
abstract mixin class _$PullRequestReviewCopyWith<$Res> implements $PullRequestReviewCopyWith<$Res> {
  factory _$PullRequestReviewCopyWith(_PullRequestReview value, $Res Function(_PullRequestReview) _then) = __$PullRequestReviewCopyWithImpl;
@override @useResult
$Res call({
 String login, PullRequestReviewState state, DateTime submittedAt
});




}
/// @nodoc
class __$PullRequestReviewCopyWithImpl<$Res>
    implements _$PullRequestReviewCopyWith<$Res> {
  __$PullRequestReviewCopyWithImpl(this._self, this._then);

  final _PullRequestReview _self;
  final $Res Function(_PullRequestReview) _then;

/// Create a copy of PullRequestReview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? login = null,Object? state = null,Object? submittedAt = null,}) {
  return _then(_PullRequestReview(
login: null == login ? _self.login : login // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PullRequestReviewState,submittedAt: null == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$PullRequestComment {

 String get id;/// `ghost` when GitHub reports no author (a deleted account).
 String get author; bool get isBot; DateTime get createdAt; PullRequestCommentOrigin get origin;/// The state of the review a thread comment belongs to; null for issue
/// comments and review summaries.
 PullRequestReviewState? get reviewState;
/// Create a copy of PullRequestComment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestCommentCopyWith<PullRequestComment> get copyWith => _$PullRequestCommentCopyWithImpl<PullRequestComment>(this as PullRequestComment, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestComment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestComment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.isBot, _this.isBot) || other.isBot == _this.isBot)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.origin, _this.origin) || other.origin == _this.origin)&&(identical(other.reviewState, _this.reviewState) || other.reviewState == _this.reviewState));
}


@override
int get hashCode {
  final _this = this as PullRequestComment;
  return Object.hash(runtimeType,_this.id,_this.author,_this.isBot,_this.createdAt,_this.origin,_this.reviewState);
}

@override
String toString() {
  final _this = this as PullRequestComment;
  return 'PullRequestComment(id: ${_this.id}, author: ${_this.author}, isBot: ${_this.isBot}, createdAt: ${_this.createdAt}, origin: ${_this.origin}, reviewState: ${_this.reviewState})';
}


}

/// @nodoc
abstract mixin class $PullRequestCommentCopyWith<$Res>  {
  factory $PullRequestCommentCopyWith(PullRequestComment value, $Res Function(PullRequestComment) _then) = _$PullRequestCommentCopyWithImpl;
@useResult
$Res call({
 String id, String author, bool isBot, DateTime createdAt, PullRequestCommentOrigin origin, PullRequestReviewState? reviewState
});




}
/// @nodoc
class _$PullRequestCommentCopyWithImpl<$Res>
    implements $PullRequestCommentCopyWith<$Res> {
  _$PullRequestCommentCopyWithImpl(this._self, this._then);

  final PullRequestComment _self;
  final $Res Function(PullRequestComment) _then;

/// Create a copy of PullRequestComment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = null,Object? isBot = null,Object? createdAt = null,Object? origin = null,Object? reviewState = freezed,}) {
  return _then(PullRequestComment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,isBot: null == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as PullRequestCommentOrigin,reviewState: freezed == reviewState ? _self.reviewState : reviewState // ignore: cast_nullable_to_non_nullable
as PullRequestReviewState?,
  ));
}

}



/// @nodoc


class _PullRequestComment implements PullRequestComment {
  const _PullRequestComment({required this.id, required this.author, required this.isBot, required this.createdAt, required this.origin, required this.reviewState});
  

@override final  String id;
/// `ghost` when GitHub reports no author (a deleted account).
@override final  String author;
@override final  bool isBot;
@override final  DateTime createdAt;
@override final  PullRequestCommentOrigin origin;
/// The state of the review a thread comment belongs to; null for issue
/// comments and review summaries.
@override final  PullRequestReviewState? reviewState;

/// Create a copy of PullRequestComment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestCommentCopyWith<_PullRequestComment> get copyWith => __$PullRequestCommentCopyWithImpl<_PullRequestComment>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestComment&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.isBot, isBot) || other.isBot == isBot)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.reviewState, reviewState) || other.reviewState == reviewState));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,author,isBot,createdAt,origin,reviewState);
}

@override
String toString() {
    return 'PullRequestComment(id: $id, author: $author, isBot: $isBot, createdAt: $createdAt, origin: $origin, reviewState: $reviewState)';
}


}

/// @nodoc
abstract mixin class _$PullRequestCommentCopyWith<$Res> implements $PullRequestCommentCopyWith<$Res> {
  factory _$PullRequestCommentCopyWith(_PullRequestComment value, $Res Function(_PullRequestComment) _then) = __$PullRequestCommentCopyWithImpl;
@override @useResult
$Res call({
 String id, String author, bool isBot, DateTime createdAt, PullRequestCommentOrigin origin, PullRequestReviewState? reviewState
});




}
/// @nodoc
class __$PullRequestCommentCopyWithImpl<$Res>
    implements _$PullRequestCommentCopyWith<$Res> {
  __$PullRequestCommentCopyWithImpl(this._self, this._then);

  final _PullRequestComment _self;
  final $Res Function(_PullRequestComment) _then;

/// Create a copy of PullRequestComment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = null,Object? isBot = null,Object? createdAt = null,Object? origin = null,Object? reviewState = freezed,}) {
  return _then(_PullRequestComment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,isBot: null == isBot ? _self.isBot : isBot // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as PullRequestCommentOrigin,reviewState: freezed == reviewState ? _self.reviewState : reviewState // ignore: cast_nullable_to_non_nullable
as PullRequestReviewState?,
  ));
}


}

/// @nodoc
mixin _$PullRequestReviewThread {

 String get id; bool get isResolved; String? get path;/// The current line, or the original line once the code moved away.
 int? get line;/// The latest 100 comments, agent replies included.
 List<PullRequestComment> get comments;
/// Create a copy of PullRequestReviewThread
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestReviewThreadCopyWith<PullRequestReviewThread> get copyWith => _$PullRequestReviewThreadCopyWithImpl<PullRequestReviewThread>(this as PullRequestReviewThread, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PullRequestReviewThread;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestReviewThread&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.isResolved, _this.isResolved) || other.isResolved == _this.isResolved)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.line, _this.line) || other.line == _this.line)&&const DeepCollectionEquality().equals(other.comments, _this.comments));
}


@override
int get hashCode {
  final _this = this as PullRequestReviewThread;
  return Object.hash(runtimeType,_this.id,_this.isResolved,_this.path,_this.line,const DeepCollectionEquality().hash(_this.comments));
}

@override
String toString() {
  final _this = this as PullRequestReviewThread;
  return 'PullRequestReviewThread(id: ${_this.id}, isResolved: ${_this.isResolved}, path: ${_this.path}, line: ${_this.line}, comments: ${_this.comments})';
}


}

/// @nodoc
abstract mixin class $PullRequestReviewThreadCopyWith<$Res>  {
  factory $PullRequestReviewThreadCopyWith(PullRequestReviewThread value, $Res Function(PullRequestReviewThread) _then) = _$PullRequestReviewThreadCopyWithImpl;
@useResult
$Res call({
 String id, bool isResolved, String? path, int? line, List<PullRequestComment> comments
});




}
/// @nodoc
class _$PullRequestReviewThreadCopyWithImpl<$Res>
    implements $PullRequestReviewThreadCopyWith<$Res> {
  _$PullRequestReviewThreadCopyWithImpl(this._self, this._then);

  final PullRequestReviewThread _self;
  final $Res Function(PullRequestReviewThread) _then;

/// Create a copy of PullRequestReviewThread
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? isResolved = null,Object? path = freezed,Object? line = freezed,Object? comments = null,}) {
  return _then(PullRequestReviewThread(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isResolved: null == isResolved ? _self.isResolved : isResolved // ignore: cast_nullable_to_non_nullable
as bool,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as List<PullRequestComment>,
  ));
}

}



/// @nodoc


class _PullRequestReviewThread implements PullRequestReviewThread {
  const _PullRequestReviewThread({required this.id, required this.isResolved, required this.path, required this.line, required  List<PullRequestComment> comments}): _comments = comments;
  

@override final  String id;
@override final  bool isResolved;
@override final  String? path;
/// The current line, or the original line once the code moved away.
@override final  int? line;
/// The latest 100 comments, agent replies included.
 final  List<PullRequestComment> _comments;
/// The latest 100 comments, agent replies included.
@override List<PullRequestComment> get comments {
  if (_comments is EqualUnmodifiableListView) return _comments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_comments);
}


/// Create a copy of PullRequestReviewThread
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestReviewThreadCopyWith<_PullRequestReviewThread> get copyWith => __$PullRequestReviewThreadCopyWithImpl<_PullRequestReviewThread>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestReviewThread&&(identical(other.id, id) || other.id == id)&&(identical(other.isResolved, isResolved) || other.isResolved == isResolved)&&(identical(other.path, path) || other.path == path)&&(identical(other.line, line) || other.line == line)&&const DeepCollectionEquality().equals(other.comments, _comments));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,isResolved,path,line,const DeepCollectionEquality().hash(_comments));
}

@override
String toString() {
    return 'PullRequestReviewThread(id: $id, isResolved: $isResolved, path: $path, line: $line, comments: $comments)';
}


}

/// @nodoc
abstract mixin class _$PullRequestReviewThreadCopyWith<$Res> implements $PullRequestReviewThreadCopyWith<$Res> {
  factory _$PullRequestReviewThreadCopyWith(_PullRequestReviewThread value, $Res Function(_PullRequestReviewThread) _then) = __$PullRequestReviewThreadCopyWithImpl;
@override @useResult
$Res call({
 String id, bool isResolved, String? path, int? line, List<PullRequestComment> comments
});




}
/// @nodoc
class __$PullRequestReviewThreadCopyWithImpl<$Res>
    implements _$PullRequestReviewThreadCopyWith<$Res> {
  __$PullRequestReviewThreadCopyWithImpl(this._self, this._then);

  final _PullRequestReviewThread _self;
  final $Res Function(_PullRequestReviewThread) _then;

/// Create a copy of PullRequestReviewThread
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? isResolved = null,Object? path = freezed,Object? line = freezed,Object? comments = null,}) {
  return _then(_PullRequestReviewThread(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,isResolved: null == isResolved ? _self.isResolved : isResolved // ignore: cast_nullable_to_non_nullable
as bool,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,comments: null == comments ? _self._comments : comments // ignore: cast_nullable_to_non_nullable
as List<PullRequestComment>,
  ));
}


}

// dart format on
