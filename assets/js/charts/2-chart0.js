google.charts.load('current', { packages: ['corechart'] });
google.charts.setOnLoadCallback(drawChart);

function drawChart() {
    var data = new google.visualization.DataTable();
    data.addColumn('number', 'Requests');
    data.addColumn('number', 'Flask');
    data.addColumn('number', 'Sanic');
    data.addRows([
        [0, 0, 0],
        [10, 1.52, 0.52],
        [20, 2.91, 0.81],
        [30, 4.43, 1.11],
        [40, 5.92, 1.29],
        [50, 7.33, 1.73]
    ]);

    var options = {
        chartArea: { width: '50%', height: '50%' },
        hAxis: { title: 'Requests', ticks: [0, 10, 20, 30, 40, 50] },
        vAxis: { title: 'Seconds  (The shorter, the better)' },
        legend: { position: 'right' },
        colors: ['red', 'blue']
    };

    var div = document.getElementById('chart0');
    var chart = new google.visualization.LineChart(div);

    chart.draw(data, options);
}
