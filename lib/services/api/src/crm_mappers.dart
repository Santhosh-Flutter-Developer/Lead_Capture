import '/constants/constants.dart';
import '/models/models.dart';
import 'dart:convert';
import 'api_attachments.dart';
import 'api_config.dart';
import 'api_mappers.dart';

/// API row -> app model mappers for the CRM modules (leads, deals, …).
/// Built through constructors only (no client-side decrypt).
class CrmMappers {
  CrmMappers._();

  static FileModel file(Map<String, dynamic> a) {
    final url = ApiConfig.resolveFileUrl(Js.s(a['file_path'] ?? a['file_url'] ?? a['url']));
    ApiAttachments.register(url, Js.i(a['id']));
    final ext = Js.s(a['file_extension'] ?? a['extension']);
    return FileModel(
      name: Js.s(a['file_name'] ?? a['name']),
      url: url,
      size: Js.i(a['file_size'] ?? a['size']) ?? 0,
      extension: ext,
      mimeType: Js.s(a['file_type'] ?? a['mime_type']),
      createdAt: Js.dt(a['created_at']),
    );
  }

  static List<FileModel> files(dynamic v) =>
      Js.mapList(v).map(file).toList();

  /// Keys the API needs to (re)link uploaded files to a record.
  static List<int> attachmentIds(List<FileModel> list) =>
      ApiAttachments.idsFor(list.map((f) => f.url));

  static LeadSourceModel _source(Map<String, dynamic> m) {
    final uid = Js.s(m['lead_source_id']);
    if (uid.isEmpty) return LeadSourceModel.fromEmptyMap();
    return LeadSourceModel(
      uid: uid,
      name: Js.s(m['source_name']),
      description: '',
      createdBy: UserDataModel.fromEmptyMap(),
    );
  }

  static LeadModel lead(Map<String, dynamic> m) {
    final createdBy = ApiMappers.createdBy(m);
    final followUp = Js.s(m['follow_up']);
    final deal = Js.m(m['deal']);
    return LeadModel(
      uid: Js.s(m['uid']),
      leadNumber: Js.i(m['lead_number']),
      salutation: Js.s(m['salutation']).isEmpty ? null : Js.s(m['salutation']),
      leadName: Js.s(m['lead_name']),
      leadEmail: Js.s(m['lead_email']),
      leadSource: _source(m),
      leadCategory: Js.s(m['lead_category_id']),
      leadPriority: Js.s(m['lead_priority_id']),
      leadValue: Js.d(m['lead_value']),
      leadStatus: Js.s(m['lead_status_id']),
      attachments: files(m['attachments']),
      notes: Js.s(m['notes']),
      companyName: Js.opt(m['company_name']),
      clientName: Js.opt(m['client_name']),
      clientMobile: Js.opt(m['client_mobile']),
      createdBy: createdBy,
      workflow: {
        if (createdBy.uid.isNotEmpty) createdBy.uid,
        if (followUp.isNotEmpty) followUp,
      }.toList(),
      clientId: Js.opt(m['client_id']),
      dealId: deal.isEmpty ? null : Js.opt(deal['uid']),
      projectName: Js.opt(m['project_name']),
      projectDescription: Js.opt(m['project_description']),
      followUp: followUp.isEmpty ? null : followUp,
      leadsConverted: Js.b(m['leads_converted']),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
    );
  }

  static LeadCommentModel leadComment(Map<String, dynamic> m) => LeadCommentModel(
        uid: Js.s(m['uid']),
        userId: Js.s(m['user_uid']),
        comment: Js.s(m['comment']),
        createdBy: UserDataModel(
          uid: Js.s(m['user_uid']),
          name: Js.s(m['user_name']),
          profilePic: ApiConfig.resolveFileUrl(Js.opt(m['user_photo'])),
          userType: UserType.employee,
        ),
        timestamp: Js.dt(m['created_at']),
      );

  static LeadHistoryModel leadHistory(Map<String, dynamic> m) => LeadHistoryModel(
        userId: Js.s(m['user_name']),
        updateDisposition: Js.s(m['action']),
        update: Js.opt(m['description']),
        timestamp: Js.dt(m['date_time']),
      );

  static LeadActivityModel leadActivity(Map<String, dynamic> m) {
    final ms = int.tryParse('${m['scheduled_at'] ?? ''}');
    final typeName = Js.s(m['type'], 'meeting');
    return LeadActivityModel(
      uid: Js.s(m['uid']),
      title: Js.s(m['title']),
      description: Js.s(m['description']),
      type: LeadActivityType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => LeadActivityType.values.first,
      ),
      scheduledAt: ms != null
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : (Js.dt(m['scheduled_at']) ?? DateTime.now()),
      createdBy: Js.s(m['created_by']),
      createdAt: Js.dt(m['created_at']) ?? DateTime.now(),
      completed: Js.b(m['completed']),
    );
  }

  static DealModel deal(Map<String, dynamic> m) {
    final createdBy = ApiMappers.createdBy(m);
    final followUp = Js.s(m['follow_up']);
    final leadId = Js.s(m['lead_id']);
    return DealModel(
      uid: Js.s(m['uid']),
      dealNumber: Js.i(m['deal_number']),
      salutation: Js.opt(m['salutation']),
      dealName: Js.s(m['deal_name']),
      dealEmail: Js.s(m['deal_email']),
      dealValue: Js.d(m['deal_value']),
      allowFollowUp: Js.b(m['allow_follow_up']),
      dealStatus: Js.opt(m['deal_status_id']),
      attachments: files(m['attachments']),
      notes: Js.s(m['notes']),
      companyName: Js.opt(m['company_name']),
      clientName: Js.opt(m['client_name']),
      clientMobile: Js.opt(m['client_mobile']),
      createdBy: createdBy,
      workFlow: {
        if (createdBy.uid.isNotEmpty) createdBy.uid,
        if (followUp.isNotEmpty) followUp,
      }.toList(),
      clientId: Js.opt(m['client_id']),
      isLocked: Js.b(m['is_locked']),
      projectName: Js.opt(m['project_name']),
      projectDescription: Js.opt(m['project_description']),
      followUp: followUp.isEmpty ? null : followUp,
      leadId: leadId.isEmpty ? null : leadId,
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
    );
  }

  static DealCommentModel dealComment(Map<String, dynamic> m) => DealCommentModel(
        uid: Js.s(m['uid']),
        userId: Js.s(m['user_uid']),
        comment: Js.s(m['comment']),
        createdBy: UserDataModel(
          uid: Js.s(m['user_uid']),
          name: Js.s(m['user_name']),
          profilePic: ApiConfig.resolveFileUrl(Js.opt(m['user_photo'])),
          userType: UserType.employee,
        ),
        timestamp: Js.dt(m['created_at']),
      );

  static DealHistoryModel dealHistory(Map<String, dynamic> m) => DealHistoryModel(
        userId: Js.s(m['user_name']),
        updateDisposition: Js.s(m['action']),
        update: Js.opt(m['description']),
        timestamp: Js.dt(m['date_time']),
      );

  static DealActivityModel dealActivity(Map<String, dynamic> m) {
    final ms = int.tryParse('${m['scheduled_at'] ?? ''}');
    final typeName = Js.s(m['type'], 'meeting');
    return DealActivityModel(
      uid: Js.s(m['uid']),
      title: Js.s(m['title']),
      description: Js.s(m['description']),
      type: DealActivityType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => DealActivityType.values.first,
      ),
      scheduledAt: ms != null
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : (Js.dt(m['scheduled_at']) ?? DateTime.now()),
      createdBy: Js.s(m['created_by']),
      createdAt: Js.dt(m['created_at']) ?? DateTime.now(),
      completed: Js.b(m['completed']),
    );
  }

  // ── locations: server stores plain names (no numeric ids) ──
  static RegionModel? country(dynamic n) => Js.s(n).isEmpty
      ? null
      : RegionModel(id: 0, currencySymbol: '', name: Js.s(n), emoji: '');
  static StateModel? stateOf(dynamic n) =>
      Js.s(n).isEmpty ? null : StateModel(id: 0, name: Js.s(n), type: '');
  static DistrictModel? district(dynamic n) =>
      Js.s(n).isEmpty ? null : DistrictModel(id: 0, name: Js.s(n));
  static CityModel? city(dynamic n) =>
      Js.s(n).isEmpty ? null : CityModel(id: 0, name: Js.s(n));

  static ClientModel client(Map<String, dynamic> m) => ClientModel(
        uid: Js.s(m['uid']),
        clientName: Js.s(m['contact_name']),
        email: Js.s(m['email']),
        mobileNumber: Js.s(m['mobile_number']),
        companyName: Js.s(m['company_name']),
        gstVatNumber: Js.opt(m['gst_vat_number']),
        officePhoneNo: Js.opt(m['office_phone_no']),
        country: country(m['country']),
        state: stateOf(m['state']),
        district: district(m['district']),
        city: city(m['city']),
        postalCode: Js.opt(m['postal_code']),
        companyAddress: Js.opt(m['company_address']),
        shippingAddress: Js.opt(m['shipping_address']),
        notes: Js.opt(m['notes']),
        isActive: true,
        isCompany: true,
        createdBy: ApiMappers.createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static MasterCompanyModel masterCompany(Map<String, dynamic> m) => MasterCompanyModel(
        uid: Js.s(m['uid']),
        companyName: Js.s(m['company_name']),
        logoUrl: Js.s(m['logo_url']).isEmpty ? null : ApiConfig.resolveFileUrl(Js.s(m['logo_url'])),
        gstVatNumber: Js.opt(m['gst_vat_number']),
        contactName: Js.s(m['contact_name']),
        mobileNumber: Js.s(m['mobile_number']),
        email: Js.opt(m['email']),
        companyAddress: Js.opt(m['company_address']),
        country: country(m['country']),
        state: stateOf(m['state']),
        district: district(m['district']),
        city: city(m['city']),
        postalCode: Js.opt(m['postal_code']),
        createdBy: ApiMappers.createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static DateTime? _ts(dynamic v) {
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return Js.dt(v);
  }

  static TaskModel task(Map<String, dynamic> m) {
    final createdByUid = Js.s(m['created_by']);
    final status = Js.opt(m['status']);
    return TaskModel(
      uid: Js.s(m['uid']),
      taskNumber: Js.i(m['task_number']),
      taskName: Js.s(m['task_name']),
      description: Js.s(m['description']),
      deadline: Js.dt(m['deadline']),
      deadlineRequired: Js.b(m['deadline_required']),
      highPriority: Js.b(m['high_priority']),
      statusSummaryRequired: Js.b(m['status_summary_required']),
      assignees: Js.strList(m['assignees_list'] ?? m['assignees']),
      createdBy: createdByUid.isEmpty ? [] : [createdByUid],
      observers: Js.strList(m['observers_list'] ?? m['observers']),
      participants: Js.strList(m['participants_list'] ?? m['participants']),
      tags: Js.strList(m['tags_list'] ?? m['tags']),
      reminder: Js.dt(m['reminder']),
      project: Js.opt(m['project']),
      hasStarted: Js.b(m['has_started']),
      startedTime: Js.dt(m['started_time']),
      status: status,
      completed: Js.b(m['completed']),
      completedTime: Js.dt(m['completed_time']),
      attachments: files(m['attachments']),
      taskCreatedBy: UserDataModel(
        uid: createdByUid,
        name: Js.s(m['created_by_name']),
        userType: UserType.employee,
      ),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
    );
  }

  static TaskCommentModel taskComment(Map<String, dynamic> m) => TaskCommentModel(
        userId: Js.s(m['user_uid']),
        comment: Js.s(m['comment']),
        timestamp: Js.dt(m['created_at']),
      );

  static TaskTimeLogModel taskTimeLog(Map<String, dynamic> m) => TaskTimeLogModel(
        userId: Js.s(m['user_uid']),
        startTime: _ts(m['start_time'] ?? m['started_at'] ?? m['start']) ?? DateTime.now(),
        endTime: _ts(m['end_time'] ?? m['ended_at'] ?? m['end']),
      );

  static T _enumByName<T extends Enum>(List<T> values, dynamic v, T fallback, [String Function(T)? label]) {
    final t = Js.s(v).replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
    for (final e in values) {
      if (e.name.toLowerCase() == t) return e;
      if (label != null && label(e).replaceAll(RegExp(r'[\s_-]'), '').toLowerCase() == t) return e;
    }
    return fallback;
  }

  static TicketCategory ticketCategory(dynamic v) =>
      _enumByName(TicketCategory.values, v, TicketCategory.technicalSupport, (e) => e.label);

  static CustomerTicketModel ticket(Map<String, dynamic> m) {
    final createdByUid = Js.s(m['created_by']);
    return CustomerTicketModel(
      uid: Js.s(m['uid']),
      ticketNumber: Js.i(m['ticket_number']),
      masterClientId: Js.opt(m['master_client_id']),
      clientName: Js.s(m['display_client_name'] ?? m['client_name']),
      clientCompanyName: Js.opt(m['client_company_name']),
      modeOfContact: _enumByName(TicketModeOfContact.values, m['mode_of_contact'], TicketModeOfContact.mail),
      ticketTitle: Js.s(m['ticket_title']),
      ticketDescription: Js.s(m['ticket_description']),
      assignTo: Js.strList(m['assign_list'] ?? m['assign_to']),
      participants: Js.strList(m['participants_list'] ?? m['participants']),
      observers: Js.strList(m['observers_list'] ?? m['observers']),
      createdBy: createdByUid.isEmpty ? [] : [createdByUid],
      attachments: files(m['attachments']),
      priorityLevel: _enumByName(TicketPriority.values, m['priority_level'] ?? m['priority'], TicketPriority.medium),
      deadline: Js.dt(m['deadline']),
      reminder: Js.dt(m['reminder']),
      category: ticketCategory(m['category']),
      status: _enumByName(TicketStatus.values, m['status'], TicketStatus.open),
      ticketCreatedBy: UserDataModel(
        uid: createdByUid,
        name: Js.s(m['created_by_name']),
        userType: UserType.employee,
      ),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
      project: Js.opt(m['project']),
      task: Js.opt(m['task']),
    );
  }

  static TicketCommentModel ticketComment(Map<String, dynamic> m) => TicketCommentModel(
        userId: Js.s(m['user_uid']),
        comment: Js.s(m['comment']),
        timestamp: Js.dt(m['created_at']),
      );

  static ProjectModel project(Map<String, dynamic> m) => ProjectModel(
        uid: Js.s(m['uid']),
        projectName: Js.s(m['project_name']),
        projectDescription: Js.s(m['project_description']),
        projectOwner: Js.s(m['project_owner']),
        teamLead: Js.s(m['team_lead']),
        members: Js.strList(m['members_list'] ?? m['members']),
        client: Js.opt(m['client_name']),
        clientId: Js.opt(m['client_id']),
        dealId: Js.opt(m['deal_id']),
        projectCode: Js.opt(m['project_code']),
        category: Js.opt(m['category']),
        startDate: Js.dt(m['start_date']),
        endDate: Js.dt(m['end_date']),
        deadline: Js.dt(m['deadline']),
        tags: Js.opt(m['tags']),
        createdBy: ApiMappers.createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static ProjectUpdationModel updation(Map<String, dynamic> m) {
    final assignee = Js.s(m['assignee_id']);
    return ProjectUpdationModel(
      uid: Js.s(m['uid']),
      updationNumber: Js.i(m['updation_number']),
      projectId: Js.s(m['project_id']),
      projectName: Js.s(m['project_name']),
      clientId: Js.opt(m['client_id']),
      companyName: Js.opt(m['company_name']),
      contactName: Js.opt(m['contact_name']),
      contactMobile: Js.opt(m['contact_mobile']),
      title: Js.s(m['title']),
      description: Js.s(m['description']),
      requestedDate: Js.dt(m['requested_date']) ?? DateTime.now(),
      status: UpdationStatusX.fromName(Js.s(m['status'])),
      value: Js.d(m['value']),
      deadline: Js.dt(m['deadline']),
      assigneeId: assignee.isEmpty ? null : assignee,
      assigneeName: Js.opt(m['assignee_name']),
      attachments: files(m['attachments']),
      notes: Js.s(m['notes']),
      followUp: assignee.isEmpty ? null : assignee,
      createdBy: ApiMappers.createdBy(m),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
    );
  }

  static PaymentModel payment(Map<String, dynamic> m) => PaymentModel(
        uid: Js.s(m['uid']),
        clientId: Js.s(m['client_id']),
        clientLabel: Js.s(m['client_label']),
        projectId: Js.s(m['project_id']),
        projectName: Js.s(m['project_name']),
        dealValue: Js.d(m['deal_value']),
        companyId: Js.s(m['master_company_id']),
        companyName: Js.s(m['master_company_name']),
        allocatedValue: Js.d(m['allocated_value']),
        paymentMode: Js.s(m['payment_mode']),
        upiNumber: Js.opt(m['upi_number']),
        updationId: Js.opt(m['updation_id']),
        updationLabel: Js.opt(m['updation_label']),
        updationValue: Js.d(m['updation_value']),
        attachments: files(m['attachments']),
        createdBy: ApiMappers.createdBy(m),
        createdAt: Js.dt(m['created_at']),
        updatedAt: Js.dt(m['updated_at']),
      );

  static NotificationModel notification(Map<String, dynamic> m, {String? myUid}) {
    final typeName = Js.s(m['type']).toLowerCase();
    NotificationType? type;
    for (final t in NotificationType.values) {
      if (t.name.toLowerCase() == typeName) type = t;
    }
    var payload = <String, dynamic>{};
    final raw = m['payload'];
    if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().startsWith('{')) {
      try {
        payload = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    final recipient = Js.s(m['recipient_uid']);
    return NotificationModel(
      uid: Js.s(m['uid']),
      title: Js.s(m['title']),
      body: Js.s(m['body']),
      type: type ?? NotificationType.info,
      createdAt: Js.dt(m['created_at']),
      toUids: recipient.isEmpty || recipient == 'all' ? [] : [recipient],
      readBy: Js.b(m['is_read']) && myUid != null ? [myUid] : [],
      senderId: Js.opt(m['sender_uid']),
      payload: payload,
    );
  }

  static EventModel event(Map<String, dynamic> m) {
    final start = Js.dt(m['start_date_time']) ?? DateTime.now();
    final rt = Js.s(m['repeat_type'], 'none');
    return EventModel(
      uid: Js.s(m['uid']),
      eventName: Js.s(m['title']),
      eventDateTime: start,
      eventEndDateTime: Js.dt(m['end_date_time']) ?? start.add(const Duration(hours: 1)),
      eventDescription: Js.s(m['description']),
      eventRepeatType: EventRepeatType.values.firstWhere(
        (e) => e.name == rt,
        orElse: () => EventRepeatType.none,
      ),
      eventAttendes: Js.strList(m['assignees_list'] ?? m['assignees']),
      createdBy: UserDataModel(
        uid: Js.s(m['created_by']),
        name: Js.s(m['created_by_name']),
        userType: UserType.employee,
      ),
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at']),
    );
  }
}
