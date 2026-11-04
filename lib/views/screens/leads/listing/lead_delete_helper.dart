import 'package:flutter/material.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';

/// Asks for confirmation, then deletes [lead] (moved to trash + activity log).
///
/// Re-checks the "Leads" delete permission right before deleting so the
/// action can never run for a role without delete access, even if a caller
/// forgot to hide its button. Returns `true` only when the lead was deleted.
Future<bool> confirmAndDeleteLead(BuildContext context, LeadModel lead) async {
  final perm = await PermissionService.getPermissions('Leads');
  if (!(perm?.canDelete ?? false)) {
    if (context.mounted) {
      FlushBar.show(
        context,
        'You do not have permission to delete leads',
        isSuccess: false,
      );
    }
    return false;
  }
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: 'Delete Lead',
      content: 'Are you sure you want to delete "${lead.leadName}"?',
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    futureLoading(context);
    await LeadService.deleteLead(uid: lead.uid ?? '');
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context); // close loading
    }
    return true;
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    if (context.mounted) {
      if (Navigator.canPop(context)) Navigator.pop(context); // close loading
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
    return false;
  }
}

/// Success toast with UNDO, shown by the screen that owns the lead list
/// after a lead was deleted. [onChanged] should reload the list.
void showLeadDeletedUndo(
  BuildContext context,
  LeadModel lead,
  VoidCallback onChanged,
) {
  FlushBar.show(
    context,
    'Lead deleted successfully',
    actionLabel: 'UNDO',
    onActionPressed: () async {
      await LeadService.restoreLead(lead);
      onChanged();
    },
  );
}

/// Outcome of [confirmAndDeleteLeads].
class LeadBulkDeleteResult {
  final List<LeadModel> deleted;
  final List<LeadModel> failed;
  const LeadBulkDeleteResult({required this.deleted, required this.failed});
}

/// Asks for confirmation, then deletes every lead in [leads] (each one is
/// moved to trash + activity log, exactly like a single delete).
///
/// Re-checks the "Leads" delete permission right before deleting. Returns
/// `null` when nothing happened (cancelled / no permission / empty list),
/// otherwise a [LeadBulkDeleteResult]. A failure on one lead does not stop
/// the others; failed leads are reported in [LeadBulkDeleteResult.failed].
Future<LeadBulkDeleteResult?> confirmAndDeleteLeads(
  BuildContext context,
  List<LeadModel> leads,
) async {
  if (leads.isEmpty) return null;

  final perm = await PermissionService.getPermissions('Leads');
  if (!(perm?.canDelete ?? false)) {
    if (context.mounted) {
      FlushBar.show(
        context,
        'You do not have permission to delete leads',
        isSuccess: false,
      );
    }
    return null;
  }
  if (!context.mounted) return null;

  final count = leads.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: count == 1 ? 'Delete Lead' : 'Delete Leads',
      content: count == 1
          ? 'Are you sure you want to delete "${leads.first.leadName}"?'
          : 'Are you sure you want to delete $count selected leads?',
    ),
  );
  if (confirmed != true || !context.mounted) return null;

  final deleted = <LeadModel>[];
  final failed = <LeadModel>[];
  futureLoading(context);
  for (final lead in leads) {
    try {
      await LeadService.deleteLead(uid: lead.uid ?? '');
      deleted.add(lead);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      failed.add(lead);
    }
  }
  if (context.mounted && Navigator.canPop(context)) {
    Navigator.pop(context); // close loading
  }
  return LeadBulkDeleteResult(deleted: deleted, failed: failed);
}

/// Toast shown after a bulk delete, with UNDO that restores every deleted
/// lead. [onChanged] should reload the list.
void showLeadsBulkDeletedUndo(
  BuildContext context,
  LeadBulkDeleteResult result,
  VoidCallback onChanged,
) {
  final ok = result.deleted.length;
  final bad = result.failed.length;

  if (ok == 0) {
    FlushBar.show(
      context,
      bad == 1
          ? 'Could not delete the selected lead'
          : 'Could not delete the selected leads',
      isSuccess: false,
    );
    return;
  }

  final message = bad == 0
      ? (ok == 1
            ? 'Lead deleted successfully'
            : '$ok leads deleted successfully')
      : '$ok deleted, $bad could not be deleted';

  FlushBar.show(
    context,
    message,
    isSuccess: bad == 0,
    actionLabel: 'UNDO',
    onActionPressed: () async {
      for (final lead in result.deleted) {
        await LeadService.restoreLead(lead);
      }
      onChanged();
    },
  );
}