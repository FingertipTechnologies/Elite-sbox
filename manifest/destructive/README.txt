Delete the PBIS_Target_Admin permission set from an org (metadata destructive deploy):

  sf project deploy start \
    --manifest manifest/destructive/package.xml \
    --post-destructive-changes manifest/destructive/destructiveChanges.xml \
    --target-org <org> --wait 30

package.xml is intentionally empty (nothing to add); destructiveChanges.xml lists what to delete.
