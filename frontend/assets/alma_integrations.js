function AlmaIntegrations($alma_integrations_form, $results_container) {
  this.$alma_integrations_form = $alma_integrations_form;
  this.$results_container = $results_container;

  this.setup_form();
}

AlmaIntegrations.prototype.setup_form = function() {
  var self = this;

  $(document).trigger("loadedrecordsubforms.aspace", this.$alma_integrations_form);

  this.$alma_integrations_form.on("submit", function(event) {
    event.preventDefault();
    self.perform_search(self.$alma_integrations_form.serializeArray());
  });
};

AlmaIntegrations.prototype.perform_search = function(data) {
  var self = this;

  self.$results_container.closest(".row").show();
  self.$results_container.html(AS.renderTemplate("template_alma_integrations_loading"));

  $.ajax({
    url: AS.app_prefix("plugins/alma_integrations/search"),
    data: data,
    type: "post",
    success: function(html) {
      $.rails.enableFormElements(self.$alma_integrations_form);
      self.$results_container.html(html);
    },
    error: function(jqHXR, textStatus, errorThrown) {
      $.rails.enableFormElements(self.$alma_integrations_form);
      var html = AS.renderTemplate("template_alma_integrations_error_message", {message: jqHXR.responseText});
      self.$results_container.html(html);
    }
  });
};

$(function() {
  var almaIntegrations = new AlmaIntegrations($("#alma_integrations_form"),
                                              $("#alma_integrations_results"));
});
