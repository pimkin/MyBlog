$(document).ready(function() {

	$("#get-data-form").submit(function(e) {

		var content = tinymce.get("texteditor").getContent();
		tinymce.triggerSave();

		/*$("#data-container").html(content);

		return false; */
	});


});