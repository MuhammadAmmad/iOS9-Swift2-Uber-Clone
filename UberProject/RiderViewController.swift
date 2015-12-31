//
//  RiderViewController.swift
//  Uber
//
//  Created by Anil Allewar on 12/21/15.
//  Copyright © 2015 Parse. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Parse

class RiderViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet var riderMapView: MKMapView!
    
    @IBOutlet var locationLabel: UILabel!
    
    let locationManager = CLLocationManager()
    
    var currentRideData: RideData = RideData()
    
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Over-ride CLLocationManagerDelegate methods
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Over-ride MKMapViewDelegate methods
        riderMapView.delegate = self
        
        let uilpgr = UILongPressGestureRecognizer(target: self, action: "longPressOnMapForAddress:")
        uilpgr.minimumPressDuration = 1.0
        self.riderMapView.addGestureRecognizer(uilpgr)
        
    }
    
    override func viewDidAppear(animated: Bool) {
        self.riderMapView.showsUserLocation = true
    }
    
    func longPressOnMapForAddress(gestureRecognizer:UILongPressGestureRecognizer){
        // Look for first long press
        if gestureRecognizer.state == UIGestureRecognizerState.Began && self.currentRideData.getCurrentRideStatus() == RideStatus.NEW {
            let touchPoint = gestureRecognizer.locationInView(self.riderMapView)
            let locationCoordOnMapForLongPress = self.riderMapView.convertPoint(touchPoint, toCoordinateFromView: self.riderMapView)
            // Remove all existing annotations
            self.riderMapView.removeAnnotations(self.riderMapView.annotations)
            
            self.getAddressFromCoordinate(locationCoordOnMapForLongPress)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currentUserLocation = locations[0]
        
        // Define zoom level
        let latDelta:CLLocationDegrees = 0.01
        let longDelta:CLLocationDegrees = 0.01
        
        let mkSpan = MKCoordinateSpanMake(latDelta, longDelta)
        
        let currentUserCoordinates = CLLocationCoordinate2DMake(currentUserLocation.coordinate.latitude, currentUserLocation.coordinate.longitude)
        
        let mkRegion = MKCoordinateRegionMake(currentUserCoordinates, mkSpan)
        
        self.riderMapView.setRegion(mkRegion, animated: true)
        
        // Stop updating now that we have the user location
        self.locationManager.stopUpdatingLocation()
        
        self.getAddressFromCoordinate(currentUserCoordinates)
    }
    
    /*
    Set the address in the PlacesData object before we add it to the array
    */
    private func getAddressFromCoordinate(currentUserCoordinates:CLLocationCoordinate2D) -> Void {
        let location:CLLocation = CLLocation(latitude: currentUserCoordinates.latitude, longitude: currentUserCoordinates.longitude)
        
        // Start spinner
        self.activityIndicator.startAnimating()
        
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
            var messageText:String = ""
            if (error != nil) {
                messageText = "Reverse Geocode failed with error: " + (error?.localizedDescription)!
            } else if let placemark = CLPlacemark?(placemarks![0]) {
                
                if let subStreet = placemark.subThoroughfare {
                    messageText += subStreet
                }
                
                if let street = placemark.thoroughfare {
                    if messageText.characters.count > 0 {
                        messageText += " " + street
                    } else {
                        messageText = street
                    }
                    
                }
                
                if let locality = placemark.locality {
                    if messageText.characters.count > 0 {
                        messageText += ", " + locality
                    } else {
                        messageText = locality
                    }
                }
                
                if let administrativeArea = placemark.administrativeArea {
                    if messageText.characters.count > 0 {
                        messageText += ", " + administrativeArea
                    } else {
                        messageText = administrativeArea
                    }
                }
                
                if let postalCode = placemark.postalCode {
                    if messageText.characters.count > 0 {
                        messageText += ", " + postalCode
                    } else {
                        messageText = postalCode
                    }
                }
                
            } else {
                messageText = "Can't find the location"
            }
            
            self.locationLabel.text = messageText
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = currentUserCoordinates
            
            self.riderMapView.addAnnotation(annotation)
            
            // Set the data to be used for requesting ride
            self.currentRideData.setAddress(messageText)
            self.currentRideData.setCoordinates(currentUserCoordinates)
            self.currentRideData.setCurrentRideStatus(RideStatus.NEW)
            
            // Stop spinner
            self.activityIndicator.stopAnimating()
        })
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "logOut"{
            PFUser.logOut()
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let reUseId = "pin"
        var pinViewAnnotation = mapView.dequeueReusableAnnotationViewWithIdentifier(reUseId)
        
        if pinViewAnnotation == nil {
            pinViewAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reUseId)
            pinViewAnnotation!.canShowCallout = true
           
            /*
            let yesImageView = UIImageView(frame: CGRectMake(0, 0, 40, 40))
            yesImageView.image = UIImage(named: "yes.jpeg")
            
            let uitgr = UITapGestureRecognizer(target: self, action: "callUberButtonTapped:")
            uitgr.numberOfTapsRequired = 1
            yesImageView.userInteractionEnabled = true
            
            yesImageView.addGestureRecognizer(uitgr)
            
            pinViewAnnotation?.rightCalloutAccessoryView = yesImageView
            */
            
        } else {
            pinViewAnnotation!.annotation = annotation
        }
        
        self.setRightAccessoryViewForCallOut(pinViewAnnotation!)

        return pinViewAnnotation
    }
    
    /*
    func callUberButtonTapped(gestureRecognizer:UIGestureRecognizer){
        print("Clicked on call button: \(gestureRecognizer.view)")
    }
    */
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let _ = view.annotation as? MKPointAnnotation {
            if self.currentRideData.getCurrentRideStatus() == RideStatus.NEW {
                self.requestRide(self.currentRideData, view: view)
            } else if self.currentRideData.getCurrentRideStatus() == RideStatus.REQUESTED || self.currentRideData.getCurrentRideStatus() == RideStatus.ACCEPTED {
                self.cancelRide(self.currentRideData, view: view)
            }
        }
    }
    
    private func setRightAccessoryViewForCallOut(annotationView:MKAnnotationView) -> Void {
        
        if let annotation = annotationView.annotation as? MKPointAnnotation {
            
            let rideButton:UIButton = UIButton(frame: CGRectMake(0, 0, 40, 40))
            
            if currentRideData.getCurrentRideStatus() == RideStatus.REQUESTED || self.currentRideData.getCurrentRideStatus() == RideStatus.ACCEPTED {
                rideButton.setImage(UIImage(named:  "cancel.jpeg"), forState: UIControlState.Normal)
                annotation.title = "Cancel Uber!"
            } else {
                rideButton.setImage(UIImage(named:  "yes.jpeg"), forState: UIControlState.Normal)
                annotation.title = "Ride Uber!"
            }
            
            annotationView.rightCalloutAccessoryView = rideButton
            
        }
    }
    
    private func requestRide(rideData:RideData, view: MKAnnotationView) {
        let currentTime = NSDate()
        
        let rideObject:PFObject = PFObject(className: "Rides")
        rideObject["riderUserId"] = PFUser.currentUser()?.objectId
        rideObject["requestedDate"] = currentTime
        rideObject["status"] = RideStatus.REQUESTED.rawValue
        rideObject["pickUpAddress"] = rideData.getAddress()
        rideObject["pickUpCoordinates"] = PFGeoPoint(latitude: rideData.getCoordinates().latitude, longitude: rideData.getCoordinates().longitude)
        
        let publicACL:PFACL = PFACL()
        publicACL.publicWriteAccess = true
        publicACL.publicReadAccess = true
        
        rideObject.ACL = publicACL
        
        rideObject.saveInBackgroundWithBlock { (success, error) -> Void in
            if error != nil {
                rideData.setCurrentRideStatus(RideStatus.NEW)
                self.showAlert("Error saving ride", message: (error?.localizedDescription)!)
            } else {
                rideData.setCurrentRideStatus(RideStatus.REQUESTED)
                rideData.setObjectId(rideObject.objectId!)
                self.setRightAccessoryViewForCallOut(view)
            }
        }
    }
    
    private func cancelRide(rideData:RideData, view: MKAnnotationView) {
        var isCancelRideConfirmed:Bool = false
        
        let alert = UIAlertController(title: "Cancel Ride", message: "Do you want to cancel the ride?", preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            self.dismissViewControllerAnimated(true, completion: nil)
            isCancelRideConfirmed = true
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .Default, handler: { (action) -> Void in
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
        
        if isCancelRideConfirmed == true {
            let rideQuery = PFQuery(className: "Rides")
            
            rideQuery.getObjectInBackgroundWithId(self.currentRideData.getObjectId()) { (result, error) -> Void in
                if error != nil {
                    self.showAlert("Error getting ride information", message: (error?.localizedDescription)!)
                } else if let object = result {
                    object["status"] = RideStatus.CANCELLED.rawValue
                    object.saveInBackgroundWithBlock({ (success, error) -> Void in
                        if error != nil {
                            self.showAlert("Error cancelling ride", message: (error?.localizedDescription)!)
                        } else {
                            // Initialize current ride
                            self.currentRideData = RideData()
                            if let annotation = view.annotation as? MKPointAnnotation {
                                self.riderMapView.removeAnnotation(annotation)
                            }
                        }
                    })
                    
                }
            }
        }
        
    }
    
    private func showAlert (title:String, message:String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }

}