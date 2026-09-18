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
    // Userview URLs end in .../{menuId}/{userviewKey} (e.g.
    // .../userview/frappeGantt/v/cloud/EA9FBB19046C44DE3677B50409A33590 -
    // last segment is the menu id, second-to-last is the userview key).
    // Extract the userview key so it can be forwarded to the popup form as
    // the "key" request parameter, letting form elements read it back via
    // the #requestParam.key# hash variable.
    function fuptda_getUserviewKey() {
        try {
            var m = window.location.pathname.match(/\/([^\/]+)\/[^\/]+\/?$/);
            return m ? m[1] : null;
        } catch (e) {
            return null;
        }
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

                        var userviewKey = fuptda_getUserviewKey();
                        if (userviewKey) {
                            params.key = userviewKey;
                        }

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
