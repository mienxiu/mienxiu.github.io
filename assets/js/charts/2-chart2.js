google.charts.load('current', { packages: ['corechart'] });
google.charts.setOnLoadCallback(drawChart);

function drawChart() {
    var data = new google.visualization.DataTable();
    data.addColumn('number', 'Requests');
    data.addColumn('number', 'Flask');
    data.addColumn('number', 'Flask(threaded)');
    data.addColumn('number', 'Sanic');
    data.addRows([
        [0, 34, 34, 130],
        [10, 34, 640, 130],
        [20, 34, 1024, 130],
        [30, 34, 1049, 130],
        [40, 34, 1297, 130],
        [50, 34, 1386, 130]
    ]);

    var options = {
        chartArea: { width: '50%', height: '50%' },
        hAxis: { title: 'Requests', ticks: [0, 10, 20, 30, 40, 50] },
        vAxis: { title: 'VIRT (MB)', logScale: true },
        legend: { position: 'right' },
        colors: ['red', 'orange', 'blue']
    };

    var div = document.getElementById('chart2');
    var chart = new google.visualization.LineChart(div);

    chart.draw(data, options);
}
