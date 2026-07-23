${htmlScript}

<div id="${element.properties.id}_div" class="bulk_complete_div" style="display:none;">
    <input type="hidden" disabled="disabled" id="formUrl" value="${contextPath}/web/app/${appDef.appId!}/${appDef.version!}/form/embed?_submitButtonLabel=${buttonLabel!?html}">
    <input type="hidden" disabled="disabled" id="json" value="${json!}">
    <input type="hidden" disabled="disabled" id="contextPath" value="${contextPath}">
    <input type="hidden" disabled="disabled" id="nonce" value="${nonceForm!?html}">
</div>
<script>
    function bulk_complete_assignment_${element.properties.id}(args) {
        JPopup.hide("bulkCompleteForm");
        
        var button = $('button[value="${element.properties.id}"]');
        button.after('<div style="display:none;"><textarea id="bulkcompleteformdata" name="bulkcompleteformdata"></textarea><input type="hidden" name="${datalist.actionParamName}" value="${element.properties.id}" /></div>');
        $("#bulkcompleteformdata").val(args.result);
        $(button).closest("form").submit();
    }
    $(document).ready(function() {
        if (!window["fuptda_bound_${element.properties.id}"]) {
            window["fuptda_bound_${element.properties.id}"] = true;
            document.addEventListener("click", function(e) {
                var btn = e.target.closest ? e.target.closest('button[value="${element.properties.id}"]') : null;
                if (!btn) {
                    return;
                }

                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();

                var button = $(btn);

                setTimeout(function() {
                    const form = button.closest("form");
                    const checkedInputs = form.find("input[type=checkbox][name|=d]:checked, input[type=radio][name|=d]:checked");

                    if (checkedInputs.length > 0) {
                        var params = {
                            _json : $("#${element.properties.id}_div").find("#json").val(),
                            _callback : "bulk_complete_assignment_${element.properties.id}",
                            _setting : "{}",
                            _nonce : $("#${element.properties.id}_div").find("#nonce").val()
                        };

                        var url = $("#${element.properties.id}_div").find("#formUrl").val();

                        if (checkedInputs.length === 1) {
                            var rowId = checkedInputs.val();
                            url += "&id=" + encodeURIComponent(rowId);
                            params._jsonFormData = JSON.stringify({ id: rowId });
                        }

                        JPopup.show("bulkCompleteForm", url, params, "", "90%", "90%");
                    } else {
                        alert("@@dbuilder.alert.noRecordSelected@@");
                    }
                }, 1000);
            }, true);
        }
    });
</script>
