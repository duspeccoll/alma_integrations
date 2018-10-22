function AlmaIntegrations($alma_integrations_form) {
  this.$alma_integrations_form = $alma_integrations_form;
  this.setup_form();
}

AlmaIntegrations.prototype.setup_form = function() {
  var self = this;
  $(document).trigger("loadedrecordsubforms.aspace", this.$alma_integrations_form);
};

$(document).ready(function() {
  var almaIntegrations = new AlmaIntegrations($("#alma_integrations_form"));
});
