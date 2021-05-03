google.charts.load('current', { packages: ['corechart'] });
google.charts.setOnLoadCallback(drawChart);

function drawChart() {
    var data = new google.visualization.DataTable();
    data.addColumn('number', 'Requests');
    data.addColumn('number', 'Flask');
    data.addColumn('number', 'Sanic');
    data.addRows([
        [0, 0, 0],
        [2, 0.94, 0.94],
        [4, 1.89, 1.88],
        [6, 2.83, 2.82],
        [8, 3.77, 3.77],
        [10, 4.73, 4.71]
    ]);

    var options = {
        chartArea: { width: '50%', height: '50%' },
        hAxis: { title: 'Requests', ticks: [0, 2, 4, 6, 8, 10] },
        vAxis: { title: 'Seconds  (The shorter, the better)', maxValue: 5 },
        legend: { position: 'right' },
        colors: ['red', 'blue']
    };

    var div = document.getElementById('chart3');
    var chart = new google.visualization.LineChart(div);

    chart.draw(data, options);
}
