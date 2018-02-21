
$(window).load(function() {
function members_call() {


    $('.pagination').hide();
    $('#test_info').hide();
    $('#test_paginate').hide();
    $( "p.pagination a" ).each(function( index ) {
//        console.log( index + ": " + $( this ).text() );
        $(this).attr("href","#")
    });
       $(document).on("click","p.pagination a",function() {
//        console.log($(this).text())
        var table =  $('#test').DataTable();

        var order = table.order();
        
        if(order)
        {
            order = order.join(',')
        }
        else
        {
            order=""
        }
        
        var subject_id = table.search();
        var info = table.page.info();

        if($(this).text()=="« Previous")
        {
        
        var a = $("#current_page_no").val();
        var b = "1";
        var page_no = parseInt(a, 10) - parseInt(b, 10);
        
        }
        
        else if ($(this).text()=="Next »")
        {
        // var page_no = $(this).text()
        var a = $("#current_page_no").val();
        var b = "1";
        var page_no = parseInt(a, 10) + parseInt(b, 10);
        
        }
        else
        {

        var page_no = $(this).text()

        }
           var project_id =  $('#test').data('project_id');
           console.log('------me---');
           console.log(project_id);
        $.ajax({
                    

            url: "/projects/datatable_values?project_id="+project_id.toString()+"&search=" + subject_id + "&length=" + info.length + "&page=" + page_no +"&order="+order, // Route to the Script Controller method
            type: "POST",
            dataType: "json",
            // This goes to Controller in params hash, i.e. params[:file_name]
            complete: function () {
            },
            success: function (data) {

                if(data.attachmentPartial) {
                    $("table.members tbody").empty();
                    $("table.members tbody").replaceWith(data.attachmentPartial)  
                    $(".member_pagination p.pagination").empty();
                    $(".member_pagination p.pagination").replaceWith(data.paginationPartial) 
                    $( ".member_pagination p.pagination a" ).each(function( index ) {
//                        console.log( index + ": " + $( this ).text() );
                        $(this).attr("href","#")
                    });

                }
            }

        });
return false;
    });

  
    //part2
    var eventFired = function ( type ) {
        var table =  $('#test').DataTable();
        var order = table.order();
        if(order)
        {
            order = order.join(',')
        }
        else
        {
            order=""
        }

        var subject_id = table.search();
        
        var info = table.page.info();
               

        if($(this).text()=="« Previous")
        {
        
        var a = $("#current_page_no").val();
        var b = "1";
        var page_no = parseInt(a, 10) - parseInt(b, 10);
        
        }
        
        else if ($(this).text()=="Next »")
        {
        // var page_no = $(this).text()
        var a = $("#current_page_no").val();
        var b = "1";
        var page_no = parseInt(a, 10) + parseInt(b, 10);
        
        }
        else
        {
        // var page_no = $("#current_page_no").val()
        var page_no = $(this).text()

        }

        var project_id =  $('#test').data('project_id');
        $.ajax({
                    

            url: "/projects/datatable_values?project_id="+project_id.toString()+"&search=" + subject_id + "&length=" + info.length + "&page=" + page_no +"&order="+order, // Route to the Script Controller method
            type: "POST",
            dataType: "json",
            // This goes to Controller in params hash, i.e. params[:file_name]
            complete: function () {
            },
            success: function (data) {
//                console.log(data.errors);
               if(data.attachmentPartial) {
                $("table.members tbody").empty();
                $("table.members tbody").replaceWith(data.attachmentPartial)  
                $(".member_pagination p.pagination").empty();
                    $(".member_pagination p.pagination").replaceWith(data.paginationPartial) 
                    $( ".member_pagination p.pagination a" ).each(function( index ) {
//                        console.log( index + ": " + $( this ).text() );
                        $(this).attr("href","#")
                    });

                }
            }
        });
    }
    
        $('#test')
            .on( 'order.dt',  function () { eventFired( 'Order' ); } )
            .on( 'search.dt', function () { eventFired( 'Search' ); } )
            .on( 'page.dt',   function () { eventFired( 'Page' ); } )
            .on( 'length.dt',   function () { eventFired( 'Length' ); } )
            .DataTable({   
                "aoColumnDefs": [ { "bSortable": false, "aTargets": [ 2, 3 ] } ],
                "order": [[ 1, "desc" ]],
                "bRetrieve": true,
                //buttons: ['csv'],
                 dom: 'Blfrt',

        });

}
    

    if ($('#tab-content-members .members').is(":visible")) {
        members_call();
        $('.pagination').show();
    }
    
    $('#tab-members').click(function(){
        members_call();
        $('.pagination').show();
    });

});
