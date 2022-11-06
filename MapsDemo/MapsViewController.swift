//
//  MapViewController.swift
//  MapsDemo
//
//  Created by Нияз Нуруллин on 05.11.2022.
//

import UIKit
import MapKit
import CoreLocation

class MapsViewController: UIViewController {

    private lazy var mapView: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        map.preferredConfiguration = MKHybridMapConfiguration()
        map.isRotateEnabled = false
        map.userTrackingMode = .followWithHeading
        map.showsCompass = true
        map.delegate = self

        return map
    }()

    private let locationManager = CLLocationManager()

    private lazy var longPressGR: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        gesture.numberOfTapsRequired = 0
        gesture.minimumPressDuration = 0.3

        return gesture
    }()

    private lazy var deleteAllPinsButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "trash.circle",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 40,
                                                                               weight: .regular,
                                                                               scale: .large)),
                        for: .normal)
        button.tintColor = .systemRed
        button.addTarget(self, action: #selector(deleteAllPins), for: .touchUpInside)

        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        viewInitialSettings()
    }

    private func viewInitialSettings() {
        getPermissionStatus()
        setupSubviews()
        showInfo()
    }

    private func setupSubviews() {
        mapView.addGestureRecognizer(longPressGR)
        view.addSubview(mapView)
        view.addSubview(deleteAllPinsButton)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            deleteAllPinsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            deleteAllPinsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deleteAllPinsButton.widthAnchor.constraint(equalToConstant: 60),
            deleteAllPinsButton.heightAnchor.constraint(equalTo: deleteAllPinsButton.widthAnchor),
        ])
    }

    private func showInfo() {
        let message: String = "To create a pin - use long gesture\nTo create route - select pin\nTo trash all pins - tap red trash button"
        let alertController = UIAlertController(title: "F.A.Q.", message: message, preferredStyle: .alert)
        let confirm = UIAlertAction(title: "Confirm", style: .default)

        alertController.addAction(confirm)
        present(alertController, animated: true)
    }

    private func getPermissionStatus() {
        let currentStatus = locationManager.authorizationStatus

        switch currentStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.desiredAccuracy = 50
            locationManager.startUpdatingLocation()
            mapView.showsUserLocation = true
            updateCurrentArea()

        case .restricted:
            debugPrint("Navigation isn't allowed.")

        case .denied:
            locationManager.stopUpdatingLocation()
            mapView.showsUserLocation = false
            debugPrint("Allow location tracking in settings.")

        @unknown default:
            preconditionFailure("Unknown error")
        }
    }

    private func updateCurrentArea() {
        guard let coordinates = locationManager.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: 1000, longitudinalMeters: 1000)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.mapView.setRegion(region, animated: true)
        }
    }

    private func addPin(_ coordinates: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinates
        mapView.addAnnotation(annotation)
        debugPrint(mapView.annotations.count)
    }

    private func showRoute(_ endPoint: CLLocationCoordinate2D) {
        let directionRequest = MKDirections.Request()
        directionRequest.transportType = .automobile

        guard let startPoint = locationManager.location?.coordinate else { return }
        let start = MKMapItem(placemark: MKPlacemark(coordinate: startPoint))
        directionRequest.source = start

        let end = MKMapItem(placemark: MKPlacemark(coordinate: endPoint))
        directionRequest.destination = end

        let direction = MKDirections(request: directionRequest)
        DispatchQueue.global().async {
            direction.calculate { response, error in
                if error == nil {
                    guard let route = response?.routes.first else { return }
                    let routeRegion = MKCoordinateRegion(route.polyline.boundingMapRect.insetBy(dx: 300, dy: 300))
                    DispatchQueue.main.async { [weak self] in
                        self?.mapView.addOverlay(route.polyline, level: .aboveRoads)
                        self?.mapView.setRegion(routeRegion, animated: true)
                    }
                } else {
                    debugPrint(error)
                }
            }
        }

    }

    @objc private func longPressAction(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            debugPrint("👇🏼👇🏼👇🏼")
            let touchLocation = sender.location(in: mapView)
            let touchCoordinates = mapView.convert(touchLocation, toCoordinateFrom: mapView)
            addPin(touchCoordinates)
        }
    }

    @objc private func deleteAllPins() {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
    }


}

// MARK: - MKMapViewDelegate
extension MapsViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        updateCurrentArea()
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        mapView.removeOverlays(mapView.overlays)
        showRoute(annotation.coordinate)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.lineWidth = 5
        renderer.strokeColor = .systemCyan

        return renderer
    }
}

// MARK: - CLLocationManagerDelegate
extension MapsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        getPermissionStatus()
    }

}
