// BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
//
// Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
//
// This program is free software; you can redistribute it and/or modify it under the
// terms of the GNU Lesser General Public License as published by the Free Software
// Foundation; either version 3.0 of the License, or (at your option) any later
// version.
//
// BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License along
// with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

$(document).on('turbolinks:load', function(){
  var controller = $("body").data('controller');
  var action = $("body").data('action');

  // Only run on the admins page.
  if (controller == "admins") {
    if(action == "index") {
      //clear the role filter if user clicks on the x
      $(".clear-role").click(function() {
        var search = new URL(location.href).searchParams.get('search')

        var url = window.location.pathname + "?page=1"
      
        if (search) {
          url += "&search=" + search
        }  
      
        window.location.replace(url);
      })

      // Handle selected user tags
      $(".manage-users-tab").click(function() {
        $(".manage-users-tab").removeClass("selected")
        $(this).addClass("selected")

        updateTabParams(this.id)
      })

      $('.selectpicker').selectpicker({
        liveSearchPlaceholder: getLocalizedString('javascript.search.start')
      });
      // Fixes turbolinks issue with bootstrap select
      $(window).trigger('load.bs.select.data-api');
      
      // Display merge accounts modal with correct info
      $(".merge-user").click(function() {
        // Update the path of save button
        $("#merge-save-access").attr("data-path", $(this).data("path"))

        let userInfo = $(this).data("info")

        $("#merge-to").html("<span>" + userInfo.name + "</span>" + "<span class='text-muted d-block'>" + userInfo.email + "</span>" + "<span class='text-muted d-block'>" + userInfo.uid + "</span>")
 
      })

      $("#mergeUserModal").on("show.bs.modal", function() {
        $(".selectpicker").selectpicker('val','')
      })
  
      $(".bootstrap-select").on("click", function() {
        $(".bs-searchbox").siblings().hide()
      })
  
      $(".bs-searchbox input").on("input", function() {
        if ($(".bs-searchbox input").val() == '' || $(".bs-searchbox input").val().length < 3) {
          $(".bs-searchbox").siblings().hide()
        } else {
          $(".bs-searchbox").siblings().show()
        }
      })

      // User selects an option from the Room Access dropdown
      $(".bootstrap-select").on("changed.bs.select", function(){
        // Get the uid of the selected user
        let user = $(".selectpicker").selectpicker('val')
        if (user != "") {
          userInfo = JSON.parse(user)
          $("#merge-from").html("<span>" + userInfo.name + "</span>" + "<span class='text-muted d-block'>" + userInfo.email + "</span>" + "<span id='from-uid' class='text-muted d-block'>" + userInfo.uid + "</span>")
        }
      })

      //PopUp user edit organization
      $("button[name='edit-organization']").click(function() {
        showEditOrganization(this);
        $("#editOrganizationModal").modal('show');
      });

      //----------------------------------------------------------------------
      //selectpicker organization
      //----------------------------------------------------------------------

      // Organization selects one from all organizations
      $(".organization .bootstrap-select").on("changed.bs.select", function() {
        // Get the uid of the selected user
        let organization = $(".organization .selectpicker").selectpicker('val')
        if (organization) {
          $("#usersbyorganization_organization").val(organization);
        }
      });

      $(".organization .bootstrap-select").on("click", function() {
        $(".bs-searchbox").siblings().hide()
      });
  
      $(".organization .bs-searchbox input").on("input", function() {
        if ($(".organization .bs-searchbox input").val() == '' || $(".organization .bs-searchbox input").val().length < 3) {
          $(".organization .bs-searchbox").siblings().hide()
        } else {
          $(".organization .bs-searchbox").siblings().show()
        }
      });
      //----------------------------------------------------------------------

    }
    else if(action == "site_settings"){
      loadColourSelectors()
    }
    else if (action == "roles"){
      // Refreshes the new role modal
      $("#newRoleButton").click(function(){
        $("#createRoleName").val("")
      })

      // Updates the colour picker to the correct colour
      role_colour = $("#role-colorinput-regular").data("colour")
      $("#role-colorinput-regular").css("background-color", role_colour);
      $("#role-colorinput-regular").css("border-color", role_colour);

      loadRoleColourSelector(role_colour, $("#role-colorinput-regular").data("disabled"));

      // Loads the jquery sortable so users can manually sort roles
      $("#rolesSelect").sortable({
        items: "a:not(.sort-disabled)",
        update: function() {
          $.ajax({
            url: $(this).data("url"),
            type: 'PATCH',
            data: $(this).sortable('serialize')
          });
        }
      });
    } else if (action == "organizations") {

      // Handle selected user tags
      $(".manage-organization-tab").click(function() {
        $(".manage-organization-tab").removeClass("selected")
        $(this).addClass("selected")

        updateTabParams(this.id)
      })

      $("#create-organization").click(function(){
        showCreateOrganization(this)
      })

      $(".edit-organization").click(function(){
        showUpdateOrganization(this)
      })
  
      $(".delete-organization").click(function() {
        showDeleteOrganization(this);
      })

      $("#deleteOrganizationModal").on("show.bs.modal", function(event) {
        $("#organization-delete-checkbox").click(organizationDeleteConfirm)
      })

      $("#createOrganizationNextinvoice").on("input",function() {

        var input = $(this).val();
        if (/\D\/$/.test(input)) input = input.substr(0, input.length - 3);
        var values = input.split('/').map(function(v) {
          return v.replace(/\D/g, '')
        });
        if (values[0]) values[0] = checkValue(values[0], 31);
        if (values[1]) values[1] = checkValue(values[1], 12);
        var output = values.map(function(v, i) {
          return v.length == 2 && i < 2 ? v + '/' : v;
        });
        $(this).val(output.join('').substr(0, 14));
        
      });

      $("#createOrganizationNextinvoice").blur(function() {

        var input = $(this).val();
        var values = input.split('/').map(function(v, i) {
          return v.replace(/\D/g, '')
        });
        var output = '';
        
        if (values.length == 3) {
          var year = values[2].length === 2 ? parseInt(values[2]) + 2000 : parseInt(values[2].substr(0, 4));
          var month = parseInt(values[1]) - 1;
          var day = parseInt(values[0]);
          var d = new Date(year, month, day);
          if (!isNaN(d)) {            
            var dates = [d.getDate(), d.getMonth() + 1, d.getFullYear()];
            output = dates.map(function(v) {
              v = v.toString();
              return v.length == 1 ? '0' + v : v;
            }).join('/');
          };
        };

        $(this).val(output);
      });
    
    } else if (action == "usersbyorganization") {

      $('[data-toggle="tooltip"]').tooltip();

      // Handle selected user tags
      $(".manage-users-tab").click(function() {
        $(".manage-users-tab").removeClass("selected")
        $(this).addClass("selected")

        updateTabParams(this.id)
      })

      $("#select_all").click(function() {
        var checked = $(this).is(':checked')
        $("[name*='user']").prop('checked', checked);
      });

      $("button[name='cbxOrganization']").click(function() {
        
        var strOrganization = $(this).html();
        var organization_id = $(this).data("value");

        $("#btnEditOrganization").html(strOrganization);
        $("#btnEditOrganization").data("value", organization_id);
        $("#usersbyorganization_organization").val(organization_id)
      });
      
    } 
  }
});

function showEditOrganization(target) {
  var modal = $(target)
  var user_uid = modal.data("user")
  var user_organization = modal.data("organization")

  $("#usersbyorganization_user_uid").val(user_uid)
  $(".organization .selectpicker").selectpicker("val", user_organization ? user_organization : "")
}

function organizationDeleteConfirm() {
  if ($("#organization-delete-checkbox").prop("checked")) {
    $("#organization-delete-confirm").removeAttr("disabled")
    $("#organization-perm-delete").hide()
    $("#organization-delete-warning").show()
  } else {
    $("#organization-delete-confirm").prop("disabled", "disabled")
    $("#organization-perm-delete").show()
    $("#organization-delete-warning").hide()
  }
}

function showCreateOrganization(target) {

  $("#createOrganizationName").val('')
  $("#createOrganizationAddress").val('')
  $("#createOrganizationPhone").val('')
  $("#createOrganizationEmail").val('')
  $("#createOrganizationMaxusers").val('')
  $("#createOrganizationNextinvoice").val('')
  $("#createOrganizationEmailVerified").prop("checked", 0)

  //show all elements & their children with a create-only class
  $(".create-only").each(function () {
    $(this).show()
    if ($(this).children().length > 0) { $(this).children().show() }
  })

  //hide all elements & their children with a update-only class
  $(".update-only").each(function () {
    $(this).attr('style', "display:none !important")
    if ($(this).children().length > 0) { $(this).children().attr('style', "display:none !important") }
  })
}

//Update the createRoomModal to show the correct current settings
function updateCurrentOrganization(organization_path) {
  // Get current room settings and set checkbox
  $.get(organization_path, function (organization) {
    $("#createOrganizationName").val(organization.name)
    $("#createOrganizationAddress").val(organization.address)
    $("#createOrganizationPhone").val(organization.phone)
    $("#createOrganizationEmail").val(organization.email)
    $("#createOrganizationMaxusers").val(organization.maxusers)
    $("#createOrganizationNextinvoice").val(moment(organization.nextinvoice.substr(0, 10)).format('DD/MM/YYYY'))
    $("#createOrganizationEmailVerified").prop("checked", organization.email_verified)
  })
}

function showUpdateOrganization(target) {
  var modal = $(target)
  var get_organization_path = modal.closest("#organization-block").data("path")
  var update_path = modal.data("path")
  
  $("#createOrganizationModal form").attr("action", update_path)

  //show all elements & their children with a update-only class
  $(".update-only").each(function() {
    $(this).show()
    if($(this).children().length > 0) { $(this).children().show() }
  })

  //hide all elements & their children with a create-only class
  $(".create-only").each(function() {
    $(this).attr('style',"display:none !important")
    if($(this).children().length > 0) { $(this).children().attr('style',"display:none !important") }
  })

  updateCurrentOrganization(get_organization_path)
}

function showDeleteOrganization(target) {
  $("#organization-delete-header").text(getLocalizedString("modal.delete_organization.confirm").replace("%{organization}", $(target).data("name")))
  $("#organization-delete-confirm").parent().attr("action", $(target).data("path"))
  organizationDeleteConfirm();
}

function checkValue(str, max) {
  if (str.charAt(0) !== '0' || str == '00') {
    var num = parseInt(str);
    if (isNaN(num) || num <= 0 || num > max) num = 1;
    str = num > parseInt(max.toString().charAt(0)) && num.toString().length == 1 ? '0' + num : num.toString();
  };
  return str;
}

function getFormattedDate(value) {
  
  if (!value) return value;

  var arr = value.split('/') ;
  return arr[2] + '-' + arr[1] + '-' + arr[0]
}

function setFormattedDate(value) {

  if (!value) return value;

  var date = new Date(value + ' GMT-0500');
  var year = date.getFullYear();

  var month = (1 + date.getMonth()).toString();
  month = month.length > 1 ? month : '0' + month;

  var day = date.getDate().toString();
  day = day.length > 1 ? day : '0' + day;

  return day + '/' + month + '/' + year;
}

// Change the branding image to the image provided
function changeBrandingImage(path) {
  var url = $("#branding-url").val()
  $.post(path, {value: url})
}

function mergeUsers() {
  let userToMerge = $("#from-uid").text()
  $.post($("#merge-save-access").data("path"), {merge: userToMerge})
}

// Filters by role
function filterRole(role) {
  var search = new URL(location.href).searchParams.get('search')

  var url = window.location.pathname + "?page=1" + "&role=" + role

  if (search) {
    url += "&search=" + search
  }  

  window.location.replace(url);
}

function updateTabParams(tab) {
  var search_params = new URLSearchParams(window.location.search)

  if (window.location.href.includes("tab=")) {
    search_params.set("tab", tab)
  } else {
    search_params.append("tab", tab)
  }

  search_params.delete("page")

  window.location.search = search_params.toString()
}

function loadColourSelectors() {
  const pickrRegular = new Pickr({
    el: '#colorinput-regular',
    theme: 'monolith',
    useAsButton: true,
    lockOpacity: true,
    defaultRepresentation: 'HEX',
    closeWithKey: 'Enter',
    default: $("#colorinput-regular").css("background-color"),

    components: {
        palette: true,
        preview: true,
        hue: true,
        interaction: {
            input: true,
            save: true,
        },
    },
  });

  const pickrLighten = new Pickr({
    el: '#colorinput-lighten',
    theme: 'monolith',
    useAsButton: true,
    lockOpacity: true,
    defaultRepresentation: 'HEX',
    closeWithKey: 'Enter',
    default: $("#colorinput-lighten").css("background-color"),

    components: {
        palette: true,
        preview: true,
        hue: true,
        interaction: {
            input: true,
            save: true,
        },
    },
  });

  const pickrDarken = new Pickr({
    el: '#colorinput-darken',
    theme: 'monolith',
    useAsButton: true,
    lockOpacity: true,
    defaultRepresentation: 'HEX',
    closeWithKey: 'Enter',
    default: $("#colorinput-darken").css("background-color"),

    components: {
        palette: true,
        preview: true,
        hue: true,
        interaction: {
            input: true,
            save: true,
        },
    },
  });

  pickrRegular.on("save", (color, instance) => {
    $.post($("#coloring-path-regular").val(), {value: color.toHEXA().toString()}).done(function() {
      location.reload()
    });
  })

  pickrLighten.on("save", (color, instance) => {
    $.post($("#coloring-path-lighten").val(), {value: color.toHEXA().toString()}).done(function() {
      location.reload()
    });
  })

  pickrDarken.on("save", (color, instance) => {
    $.post($("#coloring-path-darken").val(), {value: color.toHEXA().toString()}).done(function() {
      location.reload()
    });
  })
}

function loadRoleColourSelector(role_colour, disabled) { 
  if (!disabled) {
    const pickrRoleRegular = new Pickr({
      el: '#role-colorinput-regular',
      theme: 'monolith',
      useAsButton: true,
      lockOpacity: true,
      defaultRepresentation: 'HEX',
      closeWithKey: 'Enter',
      default: role_colour,
  
      components: {
          palette: true,
          preview: true,
          hue: true,
          interaction: {
              input: true,
              save: true,
          },
      },
    });
  
    // On save update the colour input's background colour and update the role colour input
    pickrRoleRegular.on("save", (color, instance) => {
      $("#role-colorinput-regular").css("background-color", color.toHEXA().toString());
      $("#role-colorinput-regular").css("border-color", color.toHEXA().toString());
      $("#role-colour").val(color.toHEXA().toString());
    });
  }
}